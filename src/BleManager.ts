import { NativeModules, NativeEventEmitter, EmitterSubscription } from 'react-native';
import type { BleDevice, BleService, BleScanFilter, BleScanOptions, BleState, BleConnectionState, BleNotification, ConnectionStateChange, ConnectionParameters, MtuUpdate, RssiUpdate } from './types';

const { RNBleManager } = NativeModules;

const eventEmitter = new NativeEventEmitter(RNBleManager);

export class BleManager {
  private static instance: BleManager;

  private scanSubscription?: EmitterSubscription;
  private stateSubscription?: EmitterSubscription;
  private connectionStateSubscription?: EmitterSubscription;
  private notificationSubscription?: EmitterSubscription;
  private logSubscription?: EmitterSubscription;
  private mtuSubscription?: EmitterSubscription;
  private rssiSubscription?: EmitterSubscription;

  private scanCallback?: (device: BleDevice) => void;
  private stateCallback?: (state: BleState) => void;
  private connectionStateCallback?: (change: ConnectionStateChange) => void;
  private notificationCallback?: (notification: BleNotification) => void;
  private logCallback?: (message: string) => void;
  private mtuCallback?: (update: MtuUpdate) => void;
  private rssiCallback?: (update: RssiUpdate) => void;

  static getInstance(): BleManager {
    if (!BleManager.instance) {
      BleManager.instance = new BleManager();
    }
    return BleManager.instance;
  }

  // MARK: - Event Listeners

  private setupEventListeners(): void {
    this.scanSubscription = eventEmitter.addListener('onDeviceDiscovered', (device: BleDevice) => {
      this.scanCallback?.(device);
    });

    this.stateSubscription = eventEmitter.addListener('onBluetoothStateChanged', (state: number) => {
      this.stateCallback?.(state as BleState);
    });

    this.connectionStateSubscription = eventEmitter.addListener('onConnectionStateChanged', (data: any) => {
      this.connectionStateCallback?.({
        id: data.id,
        state: data.state as BleConnectionState,
      });
    });

    this.notificationSubscription = eventEmitter.addListener('onNotificationReceived', (data: any) => {
      this.notificationCallback?.({
        id: data.id,
        characteristicUuid: data.characteristicUuid,
        value: data.value,
      });
    });

    this.logSubscription = eventEmitter.addListener('onLog', (message: string) => {
      this.logCallback?.(message);
    });

    this.mtuSubscription = eventEmitter.addListener('onMtuUpdated', (data: any) => {
      this.mtuCallback?.({
        id: data.id,
        mtu: data.mtu,
      });
    });

    this.rssiSubscription = eventEmitter.addListener('onRssiUpdated', (data: any) => {
      this.rssiCallback?.({
        id: data.id,
        rssi: data.rssi,
      });
    });
  }

  // MARK: - Scan Methods

  async startScan(
    filter?: BleScanFilter,
    options?: BleScanOptions,
    callback?: (device: BleDevice) => void
  ): Promise<void> {
    this.setupEventListeners();
    this.scanCallback = callback;

    const params: any = {};
    if (filter) {
      if (filter.serviceUUIDs?.length) {
        params.serviceUUIDs = filter.serviceUUIDs;
      }
      if (filter.name) {
        params.name = filter.name;
      }
      if (filter.namePrefix) {
        params.namePrefix = filter.namePrefix;
      }
      if (filter.manufacturerData) {
        params.manufacturerData = filter.manufacturerData;
      }
      if (filter.minRssi !== undefined) {
        params.minRssi = filter.minRssi;
      }
    }

    const opts: any = {};
    if (options) {
      if (options.scanMode !== undefined) {
        opts.scanMode = options.scanMode;
      }
      if (options.timeout !== undefined) {
        opts.timeout = options.timeout;
      }
      if (options.continuous !== undefined) {
        opts.continuous = options.continuous;
      }
      if (options.allowDuplicates !== undefined) {
        opts.allowDuplicates = options.allowDuplicates;
      }
    }

    await RNBleManager.startScan(params, opts);
  }

  async stopScan(): Promise<void> {
    await RNBleManager.stopScan();
  }

  // MARK: - Connection Methods

  async connect(
    id: string,
    timeout: number = 30.0,
    autoReconnect: boolean = true,
    params?: ConnectionParameters
  ): Promise<void> {
    this.setupEventListeners();
    await RNBleManager.connect(id, timeout, autoReconnect, params);
  }

  async disconnect(id: string): Promise<void> {
    await RNBleManager.disconnect(id);
  }

  async isConnected(id: string): Promise<boolean> {
    return await RNBleManager.isConnected(id);
  }

  // MARK: - GATT Methods

  async readCharacteristic(
    peripheralId: string,
    serviceUuid: string,
    characteristicUuid: string
  ): Promise<string> {
    return await RNBleManager.readCharacteristic(peripheralId, serviceUuid, characteristicUuid);
  }

  async writeCharacteristic(
    peripheralId: string,
    serviceUuid: string,
    characteristicUuid: string,
    value: string
  ): Promise<void> {
    await RNBleManager.writeCharacteristic(peripheralId, serviceUuid, characteristicUuid, value);
  }

  async enableNotifications(
    peripheralId: string,
    serviceUuid: string,
    characteristicUuid: string,
    enabled: boolean
  ): Promise<void> {
    await RNBleManager.enableNotifications(peripheralId, serviceUuid, characteristicUuid, enabled);
  }

  async discoverServices(peripheralId: string): Promise<BleService[]> {
    return await RNBleManager.discoverServices(peripheralId);
  }

  // MARK: - MTU Methods

  async requestMTU(peripheralId: string, mtu: number): Promise<number> {
    return await RNBleManager.requestMTU(peripheralId, mtu);
  }

  // MARK: - Connection Parameters Methods

  async updateConnectionParameters(
    peripheralId: string,
    params: ConnectionParameters
  ): Promise<void> {
    await RNBleManager.updateConnectionParameters(peripheralId, params);
  }

  // MARK: - RSSI Methods

  async readRSSI(peripheralId: string): Promise<number> {
    return await RNBleManager.readRSSI(peripheralId);
  }

  // MARK: - State Methods

  async getBluetoothState(): Promise<BleState> {
    const state = await RNBleManager.getBluetoothState();
    return state as BleState;
  }

  async getConnectionState(id: string): Promise<BleConnectionState> {
    const state = await RNBleManager.getConnectionState(id);
    return state as BleConnectionState;
  }

  // MARK: - Permissions Methods

  async requestPermissions(): Promise<void> {
    await RNBleManager.requestPermissions();
  }

  // MARK: - Callback Setters

  setOnDeviceDiscoveredCallback(callback: (device: BleDevice) => void): void {
    this.scanCallback = callback;
    this.setupEventListeners();
  }

  setOnBluetoothStateChangedCallback(callback: (state: BleState) => void): void {
    this.stateCallback = callback;
    this.setupEventListeners();
  }

  setOnConnectionStateChangedCallback(callback: (change: ConnectionStateChange) => void): void {
    this.connectionStateCallback = callback;
    this.setupEventListeners();
  }

  setOnNotificationReceivedCallback(callback: (notification: BleNotification) => void): void {
    this.notificationCallback = callback;
    this.setupEventListeners();
  }

  setOnLogCallback(callback: (message: string) => void): void {
    this.logCallback = callback;
    this.setupEventListeners();
  }

  setOnMtuUpdatedCallback(callback: (update: MtuUpdate) => void): void {
    this.mtuCallback = callback;
    this.setupEventListeners();
  }

  setOnRssiUpdatedCallback(callback: (update: RssiUpdate) => void): void {
    this.rssiCallback = callback;
    this.setupEventListeners();
  }

  // MARK: - Cleanup

  removeAllListeners(): void {
    this.scanSubscription?.remove();
    this.stateSubscription?.remove();
    this.connectionStateSubscription?.remove();
    this.notificationSubscription?.remove();
    this.logSubscription?.remove();
    this.mtuSubscription?.remove();
    this.rssiSubscription?.remove();

    this.scanCallback = undefined;
    this.stateCallback = undefined;
    this.connectionStateCallback = undefined;
    this.notificationCallback = undefined;
    this.logCallback = undefined;
    this.mtuCallback = undefined;
    this.rssiCallback = undefined;
  }
}
