# React Native BLE Manager

A comprehensive React Native Bluetooth Low Energy (BLE) library with Swift native module for iOS.

## Features

### Scan & Discovery
- **Filtered Scanning**: Filter devices by service UUIDs, name, name prefix, RSSI, and manufacturer data
- **Advertisement Data Parsing**: Parse and extract manufacturer data, service UUIDs, TX power level, and more
- **Scan Management**: Timed scans (with automatic stop) and continuous scanning
- **Scan Modes**: Low power, balanced, low latency, and opportunistic scan modes

### Connection Management
- **Multi-device Concurrent Connections**: Connect to and manage multiple devices simultaneously
- **Auto-Reconnect**: Automatic reconnection on disconnection
- **Connection Parameters**: Configure connection interval, latency, and supervision timeout
- **MTU Exchange**: Automatic MTU negotiation for optimal throughput
- **Connection Timeouts**: Specify connection timeouts

### GATT Protocol
- **Service Discovery**: Discover all services on a peripheral
- **Characteristic Operations**: Read, write, and enable/disable notifications/indications
- **Read/Write Operations**: Support for write without response and write with response
- **Notification Listening**: Real-time notification handling

### Queueing & Flow Control
- **Command Queue**: Automatic queuing of GATT operations
- **Timeout Mechanisms**: Per-operation timeout handling
- **Flow Control**: MTU-aware packetization and reassembly

### Security & Pairing
- **System Pairing Dialog**: Trigger system-level pairing popup
- **Long-Term Key Management**: Automatic management of pairing keys
- **Permission Handling**: Check and request necessary permissions (Bluetooth, location services)
- **Pairing Status Tracking**: Monitor bonding status

### Data Utilities
- **Packetization**: Automatic packet segmentation and reassembly based on MTU
- **Byte Order Conversion**: Hex string ↔ Uint8Array, little-endian and big-endian conversions
- **Type Conversion**: Convert between bytes and numeric types (uint16, int16, uint32, int32, float32, float64)
- **Text Encoding**: UTF-8 string ↔ byte array conversion

## Installation

### Using npm
```bash
npm install react-native-ble-manager
```

### Using yarn
```bash
yarn add react-native-ble-manager
```

### iOS Setup

1. In your Xcode project, add the following to your `Info.plist` file:
   ```xml
   <key>NSBluetoothAlwaysUsageDescription</key>
   <string>Need Bluetooth to connect to devices</string>
   <key>NSBluetoothPeripheralUsageDescription</key>
   <string>Need Bluetooth to connect to devices</string>
   <key>UIBackgroundModes</key>
   <array>
       <string>bluetooth-central</string>
   </array>
   ```

2. Make sure your Xcode project targets iOS 13.0 or later.

3. Run `pod install` in your `ios` directory:
   ```bash
   cd ios
   pod install
   ```

## Usage

### Basic Example

```typescript
import { BleManager } from 'react-native-ble-manager';
import type { BleDevice, BleState } from 'react-native-ble-manager';
import { DataUtils } from 'react-native-ble-manager';

const manager = BleManager.getInstance();

// Initialize
manager.setOnBluetoothStateChangedCallback((state: BleState) => {
  console.log('Bluetooth state:', state);
  if (state === BleState.POWERED_ON) {
    startScanning();
  }
});

manager.setOnDeviceDiscoveredCallback((device: BleDevice) => {
  console.log('Device discovered:', device);
});

async function startScanning() {
  await manager.startScan({
    serviceUUIDs: ['FFE0']
  }, {
    scanMode: 1, // BALANCED
    timeout: 30
  });
}

async function connectToDevice(id: string) {
  await manager.connect(id, 30000, true);
  console.log('Connected');

  const services = await manager.discoverServices(id);
  console.log('Services:', services);
}
```

### Comprehensive Usage

See [ExampleUsage.ts](./src/ExampleUsage.ts) for a complete implementation with:
- Bluetooth state monitoring
- Scanning with filters
- Connection management
- Service discovery
- Characteristic operations
- Notifications
- Large data transfer with packetization

## API Reference

### BleManager

#### Initialization
```typescript
const manager = BleManager.getInstance();
```

#### Scanning
```typescript
// Start scanning
startScan(filter?: BleScanFilter, options?: BleScanOptions, callback?: (device: BleDevice) => void): Promise<void>

// Stop scanning
stopScan(): Promise<void>
```

#### Connection
```typescript
// Connect to device
connect(id: string, timeout?: number, autoReconnect?: boolean, params?: ConnectionParameters): Promise<void>

// Disconnect from device
disconnect(id: string): Promise<void>

// Check connection status
isConnected(id: string): Promise<boolean>
```

#### GATT Operations
```typescript
// Discover services
discoverServices(id: string): Promise<BleService[]>

// Read characteristic
readCharacteristic(peripheralId: string, serviceUuid: string, characteristicUuid: string): Promise<string>

// Write characteristic
writeCharacteristic(peripheralId: string, serviceUuid: string, characteristicUuid: string, value: string): Promise<void>

// Enable/disable notifications
enableNotifications(peripheralId: string, serviceUuid: string, characteristicUuid: string, enabled: boolean): Promise<void>
```

#### State Management
```typescript
// Get Bluetooth state
getBluetoothState(): Promise<BleState>

// Get connection state
getConnectionState(id: string): Promise<BleConnectionState>
```

#### Permissions
```typescript
// Request permissions
requestPermissions(): Promise<void>
```

### DataUtils

```typescript
// Conversion methods
hexToUint8Array(hex: string): Uint8Array
uint8ArrayToHex(data: Uint8Array): string
stringToUint8Array(text: string): Uint8Array
uint8ArrayToString(data: Uint8Array): string

// Numeric conversions
uint8ArrayToUint16LE(data: Uint8Array): number
uint16LEToUint8Array(value: number): Uint8Array
uint8ArrayToInt16LE(data: Uint8Array): number
int16LEToUint8Array(value: number): Uint8Array
uint8ArrayToUint32LE(data: Uint8Array): number
uint32LEToUint8Array(value: number): Uint8Array
uint8ArrayToInt32LE(data: Uint8Array): number
int32LEToUint8Array(value: number): Uint8Array
uint8ArrayToFloat32LE(data: Uint8Array): number
float32LEToUint8Array(value: number): Uint8Array
uint8ArrayToFloat64LE(data: Uint8Array): number
float64LEToUint8Array(value: number): Uint8Array

// MTU packetization
splitIntoPackets(data: Uint8Array, mtu: number, headerSize?: number): Uint8Array[]
reassemblePackets(packets: Uint8Array[]): Uint8Array
```

## Types

### BleState
```typescript
enum BleState {
  UNKNOWN = 0,
  RESETTING,
  UNSUPPORTED,
  UNAUTHORIZED,
  POWERED_OFF,
  POWERED_ON
}
```

### BleConnectionState
```typescript
enum BleConnectionState {
  DISCONNECTED = 0,
  CONNECTING,
  CONNECTED,
  DISCONNECTING
}
```

### BleScanMode
```typescript
enum BleScanMode {
  LOW_POWER = 0,    // Battery efficient
  BALANCED,         // Default
  LOW_LATENCY,      // Fast discovery
  OPPORTUNISTIC     // Passive scanning
}
```

### BleDevice
```typescript
interface BleDevice {
  id: string;
  name?: string;
  rssi: number;
  manufacturerData?: string;
  serviceUUIDs: string[];
  txPowerLevel?: number;
  isConnectable: boolean;
}
```

### BleScanFilter
```typescript
interface BleScanFilter {
  serviceUUIDs?: string[];
  name?: string;
  namePrefix?: string;
  manufacturerData?: string;
  minRssi?: number;
}
```

### BleScanOptions
```typescript
interface BleScanOptions {
  scanMode?: BleScanMode;
  timeout?: number;
  continuous?: boolean;
  allowDuplicates?: boolean;
}
```

## Architecture

```
┌───────────────────────────────────────────────────────────┐
│                       React Native App                    │
├───────────────────────────────────────────────────────────┤
│               TypeScript API (BleManager)                 │
├───────────────────────────────────────────────────────────┤
│        Native Module Bridge (RNBleManagerBridge)           │
├───────────────────────────────────────────────────────────┤
│                    Swift Manager (BleManager)               │
├───────────────────────────────────────────────────────────┤
│              Core Bluetooth Framework (iOS)                │
└───────────────────────────────────────────────────────────┘
```

## Development

### Prerequisites
- Xcode 14.0+
- Node.js 16+
- React Native CLI
- iOS 13.0+ simulator or device

### Building from Source

1. Clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```

3. Build TypeScript:
   ```bash
   npm run build
   ```

### Running Tests

```bash
npm test
```

### Publishing

1. Update version in `package.json`
2. Build the library:
   ```bash
   npm run build
   ```

3. Publish to npm:
   ```bash
   npm publish
   ```

## Troubleshooting

### Common Issues

1. **Bluetooth not enabled**: Ensure Bluetooth is turned on and permissions are granted.

2. **Device not discovered**: Check if the device is advertising and within range.

3. **Connection fails**: Verify the device is connectable and the timeout is sufficient.

4. **Notification not received**: Ensure notifications are properly enabled and the characteristic supports notifications.

## License

MIT License

## Contributing

Contributions are welcome! Please read our [Contributing Guide](./CONTRIBUTING.md) for details.
