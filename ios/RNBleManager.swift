import Foundation
import CoreBluetooth
import React

// MARK: - Enums

@objc public enum BleState: Int {
    case unknown = 0
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn
}

@objc public enum BleConnectionState: Int {
    case disconnected = 0
    case connecting
    case connected
    case disconnecting
}

// MARK: - Models

@objc public class BleDevice: NSObject {
    @objc public let id: String
    @objc public let name: String?
    @objc public let rssi: NSNumber
    @objc public let manufacturerData: String?
    @objc public let serviceUUIDs: [String]
    @objc public let txPowerLevel: NSNumber?
    @objc public let isConnectable: Bool

    init(id: String, name: String?, rssi: NSNumber, manufacturerData: String?, serviceUUIDs: [String], txPowerLevel: NSNumber?, isConnectable: Bool) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.manufacturerData = manufacturerData
        self.serviceUUIDs = serviceUUIDs
        self.txPowerLevel = txPowerLevel
        self.isConnectable = isConnectable
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "rssi": rssi,
            "serviceUUIDs": serviceUUIDs,
            "isConnectable": isConnectable
        ]
        if let name = name { dict["name"] = name }
        if let manufacturerData = manufacturerData { dict["manufacturerData"] = manufacturerData }
        if let txPowerLevel = txPowerLevel { dict["txPowerLevel"] = txPowerLevel }
        return dict
    }
}

@objc public class BleService: NSObject {
    @objc public let uuid: String
    @objc public let isPrimary: Bool
    @objc public let characteristics: [BleCharacteristic]

    init(uuid: String, isPrimary: Bool, characteristics: [BleCharacteristic]) {
        self.uuid = uuid
        self.isPrimary = isPrimary
        self.characteristics = characteristics
    }

    func toDictionary() -> [String: Any] {
        return [
            "uuid": uuid,
            "isPrimary": isPrimary,
            "characteristics": characteristics.map { $0.toDictionary() }
        ]
    }
}

@objc public class BleCharacteristic: NSObject {
    @objc public let uuid: String
    @objc public let properties: [String]
    @objc public let value: String?

    init(uuid: String, properties: [String], value: String?) {
        self.uuid = uuid
        self.properties = properties
        self.value = value
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "uuid": uuid,
            "properties": properties
        ]
        if let value = value { dict["value"] = value }
        return dict
    }
}

// MARK: - Scan Filter

@objc public class BleScanFilter: NSObject {
    @objc public let serviceUUIDs: [String]?
    @objc public let name: String?
    @objc public let namePrefix: String?
    @objc public let manufacturerData: [UInt8]?
    @objc public let minRssi: NSNumber?

    public init(serviceUUIDs: [String]? = nil, name: String? = nil, namePrefix: String? = nil, manufacturerData: [UInt8]? = nil, minRssi: Int? = nil) {
        self.serviceUUIDs = serviceUUIDs
        self.name = name
        self.namePrefix = namePrefix
        self.manufacturerData = manufacturerData
        self.minRssi = minRssi
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let serviceUUIDs = serviceUUIDs { dict["serviceUUIDs"] = serviceUUIDs }
        if let name = name { dict["name"] = name }
        if let namePrefix = namePrefix { dict["namePrefix"] = namePrefix }
        if let manufacturerData = manufacturerData { dict["manufacturerData"] = manufacturerData.map { String(format: "%02x", $0) }.joined() }
        if let minRssi = minRssi { dict["minRssi"] = minRssi }
        return dict
    }
}

// MARK: - Scan Options

@objc public class BleScanOptions: NSObject {
    @objc public let scanMode: BleScanMode
    @objc public let timeout: TimeInterval
    @objc public let continuous: Bool
    @objc public let allowDuplicates: Bool

    public init(scanMode: BleScanMode = .balanced, timeout: TimeInterval = 10.0, continuous: Bool = false, allowDuplicates: Bool = false) {
        self.scanMode = scanMode
        self.timeout = timeout
        self.continuous = continuous
        self.allowDuplicates = allowDuplicates
    }

    func toDictionary() -> [String: Any] {
        return [
            "scanMode": scanMode.rawValue,
            "timeout": timeout,
            "continuous": continuous,
            "allowDuplicates": allowDuplicates
        ]
    }
}

@objc public enum BleScanMode: Int {
    case lowPower = 0
    case balanced = 1
    case lowLatency = 2
    case opportunistic = 3
}
