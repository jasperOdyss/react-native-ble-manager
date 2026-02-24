#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(RNBleManager, RCTEventEmitter)

// Scan Methods
RCT_EXTERN_METHOD(startScan:(NSDictionary *)filter options:(NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(stopScan:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

// Connection Methods
RCT_EXTERN_METHOD(connect:(NSString *)id timeout:(double)timeout autoReconnect:(BOOL)autoReconnect params:(NSDictionary *)params resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(disconnect:(NSString *)id resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(isConnected:(NSString *)id resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

// GATT Methods
RCT_EXTERN_METHOD(readCharacteristic:(NSString *)peripheralId serviceUuid:(NSString *)serviceUuid characteristicUuid:(NSString *)characteristicUuid resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(writeCharacteristic:(NSString *)peripheralId serviceUuid:(NSString *)serviceUuid characteristicUuid:(NSString *)characteristicUuid value:(NSString *)value resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(enableNotifications:(NSString *)peripheralId serviceUuid:(NSString *)serviceUuid characteristicUuid:(NSString *)characteristicUuid enabled:(BOOL)enabled resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(discoverServices:(NSString *)peripheralId resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

// State Methods
RCT_EXTERN_METHOD(getBluetoothState:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(getConnectionState:(NSString *)id resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

// Utility Methods
RCT_EXTERN_METHOD(requestPermissions:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_LAZY_CONSTANT(getConstants)

@end
