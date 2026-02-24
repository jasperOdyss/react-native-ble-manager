import Foundation
import React

@objc(RNBleManager)
class RNBleManager: RCTEventEmitter {

    override static func requiresMainQueueSetup() -> Bool {
        return true
    }

    override func supportedEvents() -> [String]! {
        return [
            "onBluetoothStateChanged",
            "onConnectionStateChanged",
            "onDeviceDiscovered",
            "onNotificationReceived",
            "onLog",
            "onMtuUpdated",
            "onRssiUpdated"
        ]
    }

    override func constantsToExport() -> [AnyHashable : Any]! {
        return [
            "BleState": [
                "UNKNOWN": 0,
                "RESETTING": 1,
                "UNSUPPORTED": 2,
                "UNAUTHORIZED": 3,
                "POWERED_OFF": 4,
                "POWERED_ON": 5
            ],
            "BleConnectionState": [
                "DISCONNECTED": 0,
                "CONNECTING": 1,
                "CONNECTED": 2,
                "DISCONNECTING": 3
            ],
            "BleScanMode": [
                "LOW_POWER": 0,
                "BALANCED": 1,
                "LOW_LATENCY": 2,
                "OPPORTUNISTIC": 3
            ]
        ]
    }

    // MARK: - Scan Methods

    @objc(startScan:options:resolver:rejecter:)
    func startScan(_ filter: [String: Any]?, options: [String: Any]?, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            let bleFilter: BleScanFilter? = {
                guard let filter = filter else { return nil }

                var serviceUUIDs: [String]?
                if let services = filter["serviceUUIDs"] as? [String], !services.isEmpty {
                    serviceUUIDs = services
                }

                let name = filter["name"] as? String
                let namePrefix = filter["namePrefix"] as? String

                var manufacturerData: [UInt8]?
                if let hexData = filter["manufacturerData"] as? String {
                    if let data = Data(hexString: hexData) {
                        manufacturerData = [UInt8](data)
                    }
                }

                let minRssi = filter["minRssi"] as? Int

                return BleScanFilter(
                    serviceUUIDs: serviceUUIDs,
                    name: name,
                    namePrefix: namePrefix,
                    manufacturerData: manufacturerData,
                    minRssi: minRssi
                )
            }()

            let bleOptions: BleScanOptions? = {
                guard let options = options else {
                    return BleScanOptions()
                }

                let scanModeRaw = options["scanMode"] as? Int ?? 1
                let scanMode = BleScanMode(rawValue: scanModeRaw) ?? .balanced

                let timeout = options["timeout"] as? TimeInterval ?? 10.0
                let continuous = options["continuous"] as? Bool ?? false
                let allowDuplicates = options["allowDuplicates"] as? Bool ?? false

                return BleScanOptions(
                    scanMode: scanMode,
                    timeout: timeout,
                    continuous: continuous,
                    allowDuplicates: allowDuplicates
                )
            }()

            BleManager.shared.startScan(filter: bleFilter, options: bleOptions) { device in
                self?.sendEvent(withName: "onDeviceDiscovered", body: device.toDictionary())
            }

            BleManager.shared.setLogCallback { message in
                self?.sendEvent(withName: "onLog", body: message)
            }

            BleManager.shared.setStateCallback { state in
                self?.sendEvent(withName: "onBluetoothStateChanged", body: state.rawValue)
            }

            BleManager.shared.setConnectionStateCallback { id, state in
                self?.sendEvent(withName: "onConnectionStateChanged", body: [
                    "id": id,
                    "state": state.rawValue
                ])
            }

            BleManager.shared.setNotificationCallback { id, characteristicUuid, value in
                self?.sendEvent(withName: "onNotificationReceived", body: [
                    "id": id,
                    "characteristicUuid": characteristicUuid,
                    "value": value
                ])
            }

            BleManager.shared.setMtuCallback { id, mtu in
                self?.sendEvent(withName: "onMtuUpdated", body: [
                    "id": id,
                    "mtu": mtu
                ])
            }

            BleManager.shared.setRssiCallback { id, rssi in
                self?.sendEvent(withName: "onRssiUpdated", body: [
                    "id": id,
                    "rssi": rssi
                ])
            }

            resolver(nil)
        }
    }

    @objc(stopScan:rejecter:)
    func stopScan(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            BleManager.shared.stopScan()
            resolver(nil)
        }
    }

    // MARK: - Connection Methods

    @objc(connect:timeout:autoReconnect:params:resolver:rejecter:)
    func connect(_ id: String, timeout: Double, autoReconnect: Bool, params: [String: Any]?, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            var connectionParams: BleManager.ConnectionParameters?

            if let params = params {
                let minInterval = params["minInterval"] as? TimeInterval ?? 0.0
                let maxInterval = params["maxInterval"] as? TimeInterval ?? 0.0
                let latency = params["latency"] as? Int ?? 0
                let supervisionTimeout = params["supervisionTimeout"] as? TimeInterval ?? 0.0

                connectionParams = BleManager.ConnectionParameters(
                    minInterval: minInterval,
                    maxInterval: maxInterval,
                    latency: latency,
                    supervisionTimeout: supervisionTimeout
                )
            }

            BleManager.shared.connect(id: id, timeout: timeout, autoReconnect: autoReconnect, params: connectionParams) { error in
                if let error = error {
                    rejecter("BleError", error.localizedDescription, error)
                } else {
                    resolver(nil)
                }
            }
        }
    }

    @objc(disconnect:resolver:rejecter:)
    func disconnect(_ id: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            BleManager.shared.disconnect(id: id) { error in
                if let error = error {
                    rejecter("BleError", error.localizedDescription, error)
                } else {
                    resolver(nil)
                }
            }
        }
    }

    @objc(isConnected:resolver:rejecter:)
    func isConnected(_ id: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            guard let uuid = UUID(uuidString: id), let peripheral = BleManager.shared.peripherals[uuid] else {
                resolver(false)
                return
            }

            resolver(peripheral.state == .connected)
        }
    }

    // MARK: - GATT Methods

    @objc(readCharacteristic:serviceUuid:characteristicUuid:resolver:rejecter:)
    func readCharacteristic(_ peripheralId: String, serviceUuid: String, characteristicUuid: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            BleManager.shared.readCharacteristic(peripheralId: peripheralId, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid) { value, error in
                if let error = error {
                    rejecter("BleError", error.localizedDescription, error)
                } else {
                    resolver(value)
                }
            }
        }
    }

    @objc(writeCharacteristic:serviceUuid:characteristicUuid:value:resolver:rejecter:)
    func writeCharacteristic(_ peripheralId: String, serviceUuid: String, characteristicUuid: String, value: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            BleManager.shared.writeCharacteristic(peripheralId: peripheralId, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid, value: value) { error in
                if let error = error {
                    rejecter("BleError", error.localizedDescription, error)
                } else {
                    resolver(nil)
                }
            }
        }
    }

    @objc(enableNotifications:serviceUuid:characteristicUuid:enabled:resolver:rejecter:)
    func enableNotifications(_ peripheralId: String, serviceUuid: String, characteristicUuid: String, enabled: Bool, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            BleManager.shared.enableNotifications(peripheralId: peripheralId, serviceUuid: serviceUuid, characteristicUuid: characteristicUuid, enabled: enabled) { error in
                if let error = error {
                    rejecter("BleError", error.localizedDescription, error)
                } else {
                    resolver(nil)
                }
            }
        }
    }

    @objc(discoverServices:resolver:rejecter:)
    func discoverServices(_ peripheralId: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            BleManager.shared.discoverServices(peripheralId: peripheralId) { services, error in
                if let error = error {
                    rejecter("BleError", error.localizedDescription, error)
                } else {
                    resolver(services.map { $0.toDictionary() })
                }
            }
        }
    }

    // MARK: - State Methods

    @objc(getBluetoothState:rejecter:)
    func getBluetoothState(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            let state: BleState = {
                switch BleManager.shared.centralManager.state {
                case .unknown: return .unknown
                case .resetting: return .resetting
                case .unsupported: return .unsupported
                case .unauthorized: return .unauthorized
                case .poweredOff: return .poweredOff
                case .poweredOn: return .poweredOn
                @unknown default: return .unknown
                }
            }()

            resolver(state.rawValue)
        }
    }

    @objc(getConnectionState:resolver:rejecter:)
    func getConnectionState(_ id: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            guard let uuid = UUID(uuidString: id), let peripheral = BleManager.shared.peripherals[uuid] else {
                resolver(BleConnectionState.disconnected.rawValue)
                return
            }

            let state: BleConnectionState = {
                switch peripheral.state {
                case .disconnected: return .disconnected
                case .connecting: return .connecting
                case .connected: return .connected
                case .disconnecting: return .disconnecting
                @unknown default: return .disconnected
                }
            }()

            resolver(state.rawValue)
        }
    }

    // MARK: - MTU Methods

    @objc(requestMTU:mtu:resolver:rejecter:)
    func requestMTU(_ peripheralId: String, mtu: Int, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            BleManager.shared.requestMTU(peripheralId: peripheralId, mtu: mtu) { (negotiatedMtu, error) in
                if let error = error {
                    rejecter("BleError", error.localizedDescription, error)
                } else {
                    resolver(negotiatedMtu)
                }
            }
        }
    }

    // MARK: - Connection Parameters Methods

    @objc(updateConnectionParameters:params:resolver:rejecter:)
    func updateConnectionParameters(_ peripheralId: String, params: [String: Any]?, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            var connectionParams: BleManager.ConnectionParameters?

            if let params = params {
                let minInterval = params["minInterval"] as? TimeInterval ?? 0.0
                let maxInterval = params["maxInterval"] as? TimeInterval ?? 0.0
                let latency = params["latency"] as? Int ?? 0
                let supervisionTimeout = params["supervisionTimeout"] as? TimeInterval ?? 0.0

                connectionParams = BleManager.ConnectionParameters(
                    minInterval: minInterval,
                    maxInterval: maxInterval,
                    latency: latency,
                    supervisionTimeout: supervisionTimeout
                )
            }

            BleManager.shared.updateConnectionParameters(peripheralId: peripheralId, params: connectionParams ?? BleManager.ConnectionParameters()) { error in
                if let error = error {
                    rejecter("BleError", error.localizedDescription, error)
                } else {
                    resolver(nil)
                }
            }
        }
    }

    // MARK: - RSSI Methods

    @objc(readRSSI:resolver:rejecter:)
    func readRSSI(_ peripheralId: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            BleManager.shared.readRSSI(peripheralId: peripheralId) { (rssi, error) in
                if let error = error {
                    rejecter("BleError", error.localizedDescription, error)
                } else {
                    resolver(rssi)
                }
            }
        }
    }

    // MARK: - Permissions Methods

    @objc(requestPermissions:rejecter:)
    func requestPermissions(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            // Bluetooth permissions are handled by the system
            resolver(nil)
        }
    }
}
