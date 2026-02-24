import { BleManager } from './BleManager';
import { BleDevice, BleService, BleState, BleConnectionState, BleScanFilter, BleScanOptions } from './types';
import { DataUtils, DEFAULT_TIMEOUT, MTU_MAX } from './utils/DataUtils';

class BleExample {
  private manager = BleManager.getInstance();
  private connectedPeripheralId: string | null = null;
  private rssiInterval: NodeJS.Timeout | null = null;

  async initialize() {
    // Setup listeners
    this.manager.setOnBluetoothStateChangedCallback(this.handleBluetoothStateChange);
    this.manager.setOnDeviceDiscoveredCallback(this.handleDeviceDiscovered);
    this.manager.setOnConnectionStateChangedCallback(this.handleConnectionStateChange);
    this.manager.setOnNotificationReceivedCallback(this.handleNotificationReceived);
    this.manager.setOnLogCallback(this.handleLog);
    this.manager.setOnMtuUpdatedCallback(this.handleMtuUpdated);
    this.manager.setOnRssiUpdatedCallback(this.handleRssiUpdated);

    // Check permissions
    try {
      await this.manager.requestPermissions();
      console.log('Permissions granted');
    } catch (error) {
      console.error('Permission error:', error);
    }
  }

  // MARK: - Bluetooth State
  private handleBluetoothStateChange = (state: BleState) => {
    console.log('Bluetooth state changed:', state);

    switch (state) {
      case BleState.POWERED_ON:
        this.startScanning();
        break;
      case BleState.POWERED_OFF:
        console.log('Bluetooth is off');
        break;
      case BleState.UNAUTHORIZED:
        console.error('Bluetooth not authorized');
        break;
      case BleState.UNSUPPORTED:
        console.error('Bluetooth not supported');
        break;
    }
  };

  // MARK: - Scanning
  async startScanning() {
    const filter: BleScanFilter = {
      serviceUUIDs: ['FFE0'], // Example: Heart rate monitor
      minRssi: -70,
    };

    const options: BleScanOptions = {
      scanMode: 1, // BALANCED
      timeout: 30,
      continuous: false,
    };

    try {
      await this.manager.startScan(filter, options);
      console.log('Scanning started');
    } catch (error) {
      console.error('Scan error:', error);
    }
  }

  private handleDeviceDiscovered = (device: BleDevice) => {
    console.log('Device discovered:', device);

    if (device.name?.includes('MyDevice') && this.connectedPeripheralId === null) {
      this.connectToDevice(device.id);
    }
  };

  // MARK: - Connection
  async connectToDevice(id: string) {
    try {
      await this.manager.stopScan();

      await this.manager.connect(id, DEFAULT_TIMEOUT, true, {
        minInterval: 0.0,
        maxInterval: 0.0,
        latency: 0,
        supervisionTimeout: 0.0,
      });

      this.connectedPeripheralId = id;
      console.log('Connected to:', id);

      // Request MTU negotiation
      try {
        const negotiatedMtu = await this.manager.requestMTU(id, 256);
        console.log('MTU negotiated to:', negotiatedMtu);
      } catch (error) {
        console.error('MTU negotiation error:', error);
      }

      await this.discoverServices(id);

      // Start periodic RSSI reading
      this.startPeriodicRssiReading(id);
    } catch (error) {
      console.error('Connection error:', error);
    }
  }

  private handleConnectionStateChange = (change: { id: string; state: BleConnectionState }) => {
    console.log('Connection state:', change.id, change.state);

    if (change.state === BleConnectionState.DISCONNECTED && change.id === this.connectedPeripheralId) {
      this.connectedPeripheralId = null;
      console.log('Device disconnected');
      setTimeout(() => this.startScanning(), 3000);
    }
  };

  // MARK: - GATT Operations
  async discoverServices(id: string) {
    try {
      const services: BleService[] = await this.manager.discoverServices(id);
      console.log('Services:', services);

      for (const service of services) {
        console.log('Service:', service.uuid);

        for (const characteristic of service.characteristics) {
          console.log('Characteristic:', characteristic.uuid, 'Properties:', characteristic.properties);

          // Enable notifications if available
          if (characteristic.properties.includes('NOTIFY')) {
            await this.manager.enableNotifications(id, service.uuid, characteristic.uuid, true);
          }
        }
      }
    } catch (error) {
      console.error('Service discovery error:', error);
    }
  }

  async readCharacteristic(serviceUuid: string, characteristicUuid: string) {
    if (!this.connectedPeripheralId) return;

    try {
      const value = await this.manager.readCharacteristic(
        this.connectedPeripheralId,
        serviceUuid,
        characteristicUuid
      );

      console.log('Read value:', value);

      const data = DataUtils.hexToUint8Array(value);
      console.log('Parsed data:', data);
    } catch (error) {
      console.error('Read error:', error);
    }
  }

  async writeCharacteristic(serviceUuid: string, characteristicUuid: string, data: Uint8Array) {
    if (!this.connectedPeripheralId) return;

    try {
      const hexValue = DataUtils.uint8ArrayToHex(data);
      await this.manager.writeCharacteristic(
        this.connectedPeripheralId,
        serviceUuid,
        characteristicUuid,
        hexValue
      );
      console.log('Write successful');
    } catch (error) {
      console.error('Write error:', error);
    }
  }

  // MARK: - Notifications
  private handleNotificationReceived = (notification: { id: string; characteristicUuid: string; value: string }) => {
    console.log('Notification received:', notification);

    if (notification.id === this.connectedPeripheralId) {
      try {
        const data = DataUtils.hexToUint8Array(notification.value);

        // Example: Parse heart rate data
        if (notification.characteristicUuid === 'FFE1') {
          this.parseHeartRateData(data);
        }
      } catch (error) {
        console.error('Parsing notification error:', error);
      }
    }
  };

  private parseHeartRateData(data: Uint8Array) {
    // Heart rate format depends on your device
    if (data.length > 0) {
      const heartRate = data[0];
      console.log('Heart rate:', heartRate);
    }
  }

  // MARK: - Utility Methods
  async sendLargeData(serviceUuid: string, characteristicUuid: string, largeData: Uint8Array) {
    if (!this.connectedPeripheralId) return;

    const mtu = MTU_MAX; // Adjust based on negotiation
    const packets = DataUtils.splitIntoPackets(largeData, mtu);

    for (let i = 0; i < packets.length; i++) {
      await this.writeCharacteristic(serviceUuid, characteristicUuid, packets[i]);
      await this.delay(100); // Small delay between packets
    }

    console.log('All packets sent');
  }

  private delay(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // MARK: - Cleanup
  async cleanup() {
    // Clear RSSI reading interval
    if (this.rssiInterval) {
      clearInterval(this.rssiInterval);
      this.rssiInterval = null;
    }

    if (this.connectedPeripheralId) {
      try {
        await this.manager.disconnect(this.connectedPeripheralId);
      } catch (error) {
        console.error('Disconnect error:', error);
      }
    }

    try {
      await this.manager.stopScan();
    } catch (error) {
      console.error('Stop scan error:', error);
    }

    this.manager.removeAllListeners();
    this.connectedPeripheralId = null;
  }

  private handleMtuUpdated = (update: { id: string; mtu: number }) => {
    console.log('MTU updated for device', update.id, 'to', update.mtu);

    if (update.id === this.connectedPeripheralId) {
      // Adjust packet size based on new MTU
      console.log('MTU negotiation completed, can now send larger packets');
    }
  };

  private handleRssiUpdated = (update: { id: string; rssi: number }) => {
    console.log('RSSI updated for device', update.id, 'to', update.rssi);

    if (update.id === this.connectedPeripheralId) {
      // Handle RSSI change, e.g. signal strength indication
      if (update.rssi < -80) {
        console.log('Weak signal strength');
      } else if (update.rssi > -60) {
        console.log('Strong signal strength');
      }
    }
  };

  private startPeriodicRssiReading(id: string) {
    // Read RSSI every 5 seconds
    this.rssiInterval = setInterval(async () => {
      try {
        const rssi = await this.manager.readRSSI(id);
        console.log('Periodic RSSI read:', rssi);
      } catch (error) {
        console.error('RSSI read error:', error);
      }
    }, 5000);
  }

  async updateConnectionParams() {
    if (!this.connectedPeripheralId) return;

    try {
      await this.manager.updateConnectionParameters(this.connectedPeripheralId, {
        minInterval: 30,  // 30ms
        maxInterval: 60,  // 60ms
        latency: 4,       // 4 connection events
        supervisionTimeout: 10000  // 10 seconds
      });
      console.log('Connection parameters updated');
    } catch (error) {
      console.error('Connection parameters update error:', error);
    }
  }

  private handleLog = (message: string) => {
    console.log('[BleManager]', message);
  };
}

// Usage example
const bleExample = new BleExample();
export default bleExample;
