import Foundation
import CoreBluetooth

class BleManager: NSObject {
    static let shared = BleManager()

    private var centralManager: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var pendingConnections: [UUID: ConnectionParams] = [:]
    private var autoReconnectMap: [UUID: Bool] = [:]
    private var connectionParameters: [UUID: ConnectionParameters] = [:]

    private var scanTimer: Timer?
    private var discoveredDevices: [UUID: BleDevice] = [:]
    private var scanCallback: ((BleDevice) -> Void)?
    private var scanFilter: BleScanFilter?
    private var scanOptions: BleScanOptions?

    private var stateCallback: ((BleState) -> Void)?
    private var connectionStateCallback: ((String, BleConnectionState) -> Void)?
    private var notificationCallback: ((String, String, String) -> Void)?
    private var logCallback: ((String) -> Void)?
    private var mtuCallback: ((String, Int) -> Void)?
    private var rssiCallback: ((String, Int) -> Void)?

    override private init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue(label: "BleManagerQueue"))
    }

    // MARK: - Public API

    func startScan(filter: BleScanFilter?, options: BleScanOptions?, callback: @escaping (BleDevice) -> Void) {
        scanCallback = callback
        scanFilter = filter
        scanOptions = options

        discoveredDevices.removeAll()

        let cbOptions: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: options?.allowDuplicates ?? false
        ]

        if let serviceUUIDs = filter?.serviceUUIDs {
            let uuids = serviceUUIDs.compactMap { CBUUID(string: $0) }
            centralManager.scanForPeripherals(withServices: uuids, options: cbOptions)
        } else {
            centralManager.scanForPeripherals(withServices: nil, options: cbOptions)
        }

        if !options?.continuous ?? false {
            scanTimer?.invalidate()
            scanTimer = Timer.scheduledTimer(withTimeInterval: options?.timeout ?? 10.0, repeats: false) { [weak self] _ in
                self?.stopScan()
            }
        }
    }

    func stopScan() {
        centralManager.stopScan()
        scanTimer?.invalidate()
        scanTimer = nil
    }

    func connect(id: String, timeout: TimeInterval = 30.0, autoReconnect: Bool = true, params: ConnectionParameters? = nil, completion: @escaping (Error?) -> Void) {
        guard let uuid = UUID(uuidString: id) else {
            completion(NSError(domain: "BleError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid UUID"]))
            return
        }

        autoReconnectMap[uuid] = autoReconnect

        if let peripheral = peripherals[uuid] {
            connectToPeripheral(peripheral, timeout: timeout, params: params, completion: completion)
        } else if let peripheral = centralManager.retrievePeripherals(withIdentifiers: [uuid]).first {
            peripherals[uuid] = peripheral
            connectToPeripheral(peripheral, timeout: timeout, params: params, completion: completion)
        } else {
            completion(NSError(domain: "BleError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Peripheral not found"]))
        }
    }

    func disconnect(id: String, completion: @escaping (Error?) -> Void) {
        guard let uuid = UUID(uuidString: id), let peripheral = peripherals[uuid] else {
            completion(NSError(domain: "BleError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Peripheral not found"]))
            return
        }

        autoReconnectMap[uuid] = false
        centralManager.cancelPeripheralConnection(peripheral)
        completion(nil)
    }

    func readCharacteristic(peripheralId: String, serviceUuid: String, characteristicUuid: String, completion: @escaping (String?, Error?) -> Void) {
        guard let peripheral = getPeripheral(peripheralId) else {
            completion(nil, NSError(domain: "BleError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Peripheral not found"]))
            return
        }

        let serviceCBUUID = CBUUID(string: serviceUuid)
        let charCBUUID = CBUUID(string: characteristicUuid)

        findCharacteristic(peripheral: peripheral, serviceCBUUID: serviceCBUUID, charCBUUID: charCBUUID) { characteristic in
            guard let characteristic = characteristic else {
                completion(nil, NSError(domain: "BleError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Characteristic not found"]))
                return
            }

            peripheral.readValue(for: characteristic)
            // Value will be received in peripheral(_:didUpdateValueFor:error:)
        }
    }

    func writeCharacteristic(peripheralId: String, serviceUuid: String, characteristicUuid: String, value: String, completion: @escaping (Error?) -> Void) {
        guard let peripheral = getPeripheral(peripheralId) else {
            completion(NSError(domain: "BleError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Peripheral not found"]))
            return
        }

        guard let data = Data(hexString: value) else {
            completion(NSError(domain: "BleError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid hex string"]))
            return
        }

        let serviceCBUUID = CBUUID(string: serviceUuid)
        let charCBUUID = CBUUID(string: characteristicUuid)

        findCharacteristic(peripheral: peripheral, serviceCBUUID: serviceCBUUID, charCBUUID: charCBUUID) { characteristic in
            guard let characteristic = characteristic else {
                completion(NSError(domain: "BleError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Characteristic not found"]))
                return
            }

            if characteristic.properties.contains(.writeWithoutResponse) {
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            } else if characteristic.properties.contains(.write) {
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
            } else {
                completion(NSError(domain: "BleError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Characteristic not writable"]))
            }
        }
    }

    func enableNotifications(peripheralId: String, serviceUuid: String, characteristicUuid: String, enabled: Bool, completion: @escaping (Error?) -> Void) {
        guard let peripheral = getPeripheral(peripheralId) else {
            completion(NSError(domain: "BleError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Peripheral not found"]))
            return
        }

        let serviceCBUUID = CBUUID(string: serviceUuid)
        let charCBUUID = CBUUID(string: characteristicUuid)

        findCharacteristic(peripheral: peripheral, serviceCBUUID: serviceCBUUID, charCBUUID: charCBUUID) { characteristic in
            guard let characteristic = characteristic else {
                completion(NSError(domain: "BleError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Characteristic not found"]))
                return
            }

            peripheral.setNotifyValue(enabled, for: characteristic)
            completion(nil)
        }
    }

    func discoverServices(peripheralId: String, completion: @escaping ([BleService], Error?) -> Void) {
        guard let peripheral = getPeripheral(peripheralId) else {
            completion([], NSError(domain: "BleError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Peripheral not found"]))
            return
        }

        peripheral.discoverServices(nil)
        // Services will be discovered in peripheral(_:didDiscoverServices:)
    }

    func requestMTU(peripheralId: String, mtu: Int, completion: @escaping (Int?, Error?) -> Void) {
        guard let peripheral = getPeripheral(peripheralId) else {
            completion(nil, NSError(domain: "BleError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Peripheral not found"]))
            return
        }

        peripheral.maximumWriteValueLength(for: .withResponse) // This triggers MTU negotiation in some cases
        // Note: In iOS, MTU negotiation is handled automatically upon connection
        completion(peripheral.maximumWriteValueLength(for: .withResponse) + 3, nil)
    }

    func updateConnectionParameters(peripheralId: String, params: ConnectionParameters, completion: @escaping (Error?) -> Void) {
        guard let peripheral = getPeripheral(peripheralId) else {
            completion(NSError(domain: "BleError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Peripheral not found"]))
            return
        }

        connectionParameters[peripheral.identifier] = params
        // In iOS, connection parameters are managed by the system
        completion(nil)
    }

    func readRSSI(peripheralId: String, completion: @escaping (Int?, Error?) -> Void) {
        guard let peripheral = getPeripheral(peripheralId) else {
            completion(nil, NSError(domain: "BleError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Peripheral not found"]))
            return
        }

        peripheral.readRSSI()
        // RSSI will be read in peripheral(_:didReadRSSI:error:)
    }

    // MARK: - Internal Methods

    private func connectToPeripheral(_ peripheral: CBPeripheral, timeout: TimeInterval, params: ConnectionParameters?, completion: @escaping (Error?) -> Void) {
        let connectionParams = ConnectionParams(timeout: timeout, completion: completion, params: params)
        pendingConnections[peripheral.identifier] = connectionParams

        centralManager.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])

        // Set connection timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            if let pending = self?.pendingConnections[peripheral.identifier] {
                self?.pendingConnections.removeValue(forKey: peripheral.identifier)
                self?.centralManager.cancelPeripheralConnection(peripheral)
                pending.completion(NSError(domain: "BleError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Connection timeout"]))
            }
        }
    }

    private func findCharacteristic(peripheral: CBPeripheral, serviceCBUUID: CBUUID, charCBUUID: CBUUID, completion: @escaping (CBCharacteristic?) -> Void) {
        if let service = peripheral.services?.first(where: { $0.uuid == serviceCBUUID }),
           let characteristic = service.characteristics?.first(where: { $0.uuid == charCBUUID }) {
            completion(characteristic)
        } else {
            peripheral.discoverServices([serviceCBUUID])
        }
    }

    private func getPeripheral(_ id: String) -> CBPeripheral? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return peripherals[uuid]
    }

    private func log(_ message: String) {
        logCallback?(message)
        print("[BleManager] \(message)")
    }

    // MARK: - Property Setters

    func setLogCallback(_ callback: @escaping (String) -> Void) {
        logCallback = callback
    }

    func setStateCallback(_ callback: @escaping (BleState) -> Void) {
        stateCallback = callback
    }

    func setConnectionStateCallback(_ callback: @escaping (String, BleConnectionState) -> Void) {
        connectionStateCallback = callback
    }

    func setNotificationCallback(_ callback: @escaping (String, String, String) -> Void) {
        notificationCallback = callback
    }

    func setMtuCallback(_ callback: @escaping (String, Int) -> Void) {
        mtuCallback = callback
    }

    func setRssiCallback(_ callback: @escaping (String, Int) -> Void) {
        rssiCallback = callback
    }

    // MARK: - Connection Parameters

    struct ConnectionParameters {
        let minInterval: TimeInterval
        let maxInterval: TimeInterval
        let latency: Int
        let supervisionTimeout: TimeInterval

        init(minInterval: TimeInterval = 0.0, maxInterval: TimeInterval = 0.0, latency: Int = 0, supervisionTimeout: TimeInterval = 0.0) {
            self.minInterval = minInterval
            self.maxInterval = maxInterval
            self.latency = latency
            self.supervisionTimeout = supervisionTimeout
        }
    }

    private struct ConnectionParams {
        let timeout: TimeInterval
        let completion: (Error?) -> Void
        let params: ConnectionParameters?
    }
}

// MARK: - CBCentralManagerDelegate

extension BleManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state: BleState = {
            switch central.state {
            case .unknown: return .unknown
            case .resetting: return .resetting
            case .unsupported: return .unsupported
            case .unauthorized: return .unauthorized
            case .poweredOff: return .poweredOff
            case .poweredOn: return .poweredOn
            @unknown default: return .unknown
            }
        }()

        stateCallback?(state)
        log("Bluetooth state changed: \(state.rawValue)")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let device = createBleDevice(from: peripheral, advertisementData: advertisementData, rssi: RSSI)

        if shouldFilterDevice(device) {
            return
        }

        discoveredDevices[peripheral.identifier] = device
        peripherals[peripheral.identifier] = peripheral
        scanCallback?(device)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("Peripheral connected: \(peripheral.identifier.uuidString)")

        if let pending = pendingConnections.removeValue(forKey: peripheral.identifier) {
            pending.completion(nil)

            if let params = pending.params {
                connectionParameters[peripheral.identifier] = params
            }
        }

        peripheral.delegate = self
        peripheral.discoverServices(nil)

        connectionStateCallback?(peripheral.identifier.uuidString, .connected)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("Peripheral disconnected: \(peripheral.identifier.uuidString), error: \(error?.localizedDescription ?? "none")")

        if let autoReconnect = autoReconnectMap[peripheral.identifier], autoReconnect {
            log("Auto-reconnecting to peripheral: \(peripheral.identifier.uuidString)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                if let connectionParams = self?.connectionParameters[peripheral.identifier] {
                    self?.connectToPeripheral(peripheral, timeout: 30.0, params: connectionParams, completion: { _ in })
                } else {
                    self?.connectToPeripheral(peripheral, timeout: 30.0, params: nil, completion: { _ in })
                }
            }
        }

        connectionStateCallback?(peripheral.identifier.uuidString, .disconnected)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("Failed to connect to peripheral: \(peripheral.identifier.uuidString), error: \(error?.localizedDescription ?? "none")")

        if let pending = pendingConnections.removeValue(forKey: peripheral.identifier) {
            pending.completion(error)
        }

        connectionStateCallback?(peripheral.identifier.uuidString, .disconnected)
    }

    private func createBleDevice(from peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) -> BleDevice {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let manufacturerData = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data)?.hexString
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.compactMap { $0.uuidString } ?? []
        let txPowerLevel = advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? Bool) ?? true

        return BleDevice(
            id: peripheral.identifier.uuidString,
            name: name,
            rssi: rssi,
            manufacturerData: manufacturerData,
            serviceUUIDs: serviceUUIDs,
            txPowerLevel: txPowerLevel,
            isConnectable: isConnectable
        )
    }

    private func shouldFilterDevice(_ device: BleDevice) -> Bool {
        guard let filter = scanFilter else { return false }

        if let minRssi = filter.minRssi, device.rssi.intValue < minRssi {
            return true
        }

        if let name = filter.name, device.name != name {
            return true
        }

        if let namePrefix = filter.namePrefix, !(device.name?.starts(with: namePrefix) ?? false) {
            return true
        }

        return false
    }
}

// MARK: - CBPeripheralDelegate

extension BleManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            log("Failed to discover services: \(error?.localizedDescription ?? "unknown error")")
            return
        }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            log("Failed to discover characteristics: \(error?.localizedDescription ?? "unknown error")")
            return
        }

        log("Discovered \(characteristics.count) characteristics for service: \(service.uuid.uuidString)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else {
            log("No data received: \(error?.localizedDescription ?? "unknown error")")
            return
        }

        let hexValue = data.hexString
        log("Data received: \(hexValue)")

        notificationCallback?(peripheral.identifier.uuidString, characteristic.uuid.uuidString, hexValue)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        log("Notification state changed for characteristic: \(characteristic.uuid.uuidString), enabled: \(characteristic.isNotifying), error: \(error?.localizedDescription ?? "none")")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        log("Write completed for characteristic: \(characteristic.uuid.uuidString), error: \(error?.localizedDescription ?? "none")")
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        log("RSSI read: \(RSSI.intValue), error: \(error?.localizedDescription ?? "none")")

        if let error = error {
            log("RSSI read error: \(error.localizedDescription)")
        } else {
            rssiCallback?(peripheral.identifier.uuidString, RSSI.intValue)
        }
    }
}

// MARK: - Data Extensions

extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }

    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2) else { return nil }

        var data = Data()
        var index = hexString.startIndex

        while index < hexString.endIndex {
            let endIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<endIndex], radix: 16) else { return nil }
            data.append(byte)
            index = endIndex
        }

        self = data
    }
}
