export enum BleState {
  UNKNOWN = 0,
  RESETTING,
  UNSUPPORTED,
  UNAUTHORIZED,
  POWERED_OFF,
  POWERED_ON,
}

export enum BleConnectionState {
  DISCONNECTED = 0,
  CONNECTING,
  CONNECTED,
  DISCONNECTING,
}

export enum BleScanMode {
  LOW_POWER = 0,
  BALANCED,
  LOW_LATENCY,
  OPPORTUNISTIC,
}

export enum BleErrorType {
  UNKNOWN = 0,
  BLUETOOTH_OFF,
  UNAUTHORIZED,
  UNSUPPORTED,
  TIMEOUT,
  CONNECTION_FAILED,
  DISCONNECTED,
  SERVICE_DISCOVERY_FAILED,
  CHARACTERISTIC_NOT_FOUND,
  READ_FAILED,
  WRITE_FAILED,
  NOTIFICATION_FAILED,
  MTU_NEGOTIATION_FAILED,
  CONNECTION_PARAMETER_UPDATE_FAILED,
  RSSI_READ_FAILED,
  PERMISSION_DENIED,
  SCAN_FAILED,
}

export interface BleError {
  type: BleErrorType;
  message: string;
  code?: number;
}

export interface BleDevice {
  id: string;
  name?: string;
  rssi: number;
  manufacturerData?: string;
  serviceUUIDs: string[];
  txPowerLevel?: number;
  isConnectable: boolean;
}

export interface BleService {
  uuid: string;
  isPrimary: boolean;
  characteristics: BleCharacteristic[];
}

export interface BleCharacteristic {
  uuid: string;
  properties: string[];
  value?: string;
}

export interface BleScanFilter {
  serviceUUIDs?: string[];
  name?: string;
  namePrefix?: string;
  manufacturerData?: string;
  minRssi?: number;
}

export interface BleScanOptions {
  scanMode?: BleScanMode;
  timeout?: number;
  continuous?: boolean;
  allowDuplicates?: boolean;
}

export interface ConnectionParameters {
  minInterval?: number;
  maxInterval?: number;
  latency?: number;
  supervisionTimeout?: number;
}

export interface BleNotification {
  id: string;
  characteristicUuid: string;
  value: string;
}

export interface ConnectionStateChange {
  id: string;
  state: BleConnectionState;
}

export interface MtuUpdate {
  id: string;
  mtu: number;
}

export interface RssiUpdate {
  id: string;
  rssi: number;
}
