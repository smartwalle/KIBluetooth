//
//  KIPeripheral.h
//  Kitalker
//
//  Created by Kitalker on 14-1-16.
//  Copyright (c) 2014年 杨 烽. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "CBUUID+KIAdditions.h"

#define kConnectTimeoutCode                 90110
#define kConnectTimeoutMsg                  @"Connect timeout"

#define kFindServiceFailedCode              90111
#define kFindServiceFailedMsg               @"find service failed"

#define kFindCharacteristicsFailedCode      90112
#define kFindCharacteristicsFailedMsg       @"find characteristics failed"

#define kDisconnectCode                     90113
#define kDisconnectMsg                      @"disconnect"

#define kWriteValueErrorCode                90114
#define kWriteValueErrorMsg                 @"empty data"

@class KIPeripheral;

typedef void(^DidUpdateConnectStateBlock)               (KIPeripheral *peripheral);

typedef void(^DidDiscoverSpecialServiceBlock)           (KIPeripheral *peripheral, CBService *service, NSError *error);
typedef void(^DidDiscoverServicesBlock)                 (KIPeripheral *peripheral, NSArray *services, NSError *error);

typedef void(^DidDiscoverSpecialCharacteristicsBlock)   (KIPeripheral *peripheral, CBService *service, CBCharacteristic *characteristic, NSError *error);
typedef void(^DidDiscoverCharacteristicsBlock)          (KIPeripheral *peripheral, CBService *service, NSArray *characteristics, NSError *error);

typedef void(^DidWriteValueForCharacteristicBlock)      (KIPeripheral *peripheral, CBService *service, CBCharacteristic *characteristic, NSError *error);
typedef void(^DidReadValueForCharacteristicBLock)       (KIPeripheral *peripheral, CBService *service, CBCharacteristic *characteristic, NSData *value, NSError *error);

typedef void(^DidUpdateRSSIBlock)                               (KIPeripheral *peripheral, NSNumber *RSSI, NSError *error);
typedef void(^DidUpdateNotificationStateForCharacteristicBlock) (KIPeripheral *peripheral, CBService *service, CBCharacteristic *characteristic, BOOL isUpdateState, NSData *value, NSError *error);

@interface KIPeripheral : NSObject <CBPeripheralDelegate>

@property (nonatomic,strong) NSDictionary *advertisementData;

/*iOS6*/
@property (readonly, nonatomic) CFUUIDRef UUID NS_DEPRECATED(NA, NA, 5_0, 7_0);

/*iOS7*/
@property (readonly, nonatomic) NSUUID *identifier;

/*用这个来获取uuid*/
@property (readonly, nonatomic) NSString *UUIDString;

@property (retain, readonly) NSString *name;

@property (retain, readonly) NSNumber *RSSI;

/*iOS7 如果只是判断是否连接，使用 isConnected*/
@property (readonly) CBPeripheralState state;

@property (retain, readonly) NSArray *services;

- (id)initWithPeripheral:(CBPeripheral *)peripheral;

- (CBPeripheral *)peripheral;

/*用于判断连接状态，兼容6和7*/
- (BOOL)isConnected;

- (void)readRSSI:(DidUpdateRSSIBlock)block;

- (void)readRSSIWithRealtime:(BOOL)realtime frameInterval:(NSInteger)frameInterval complete:(DidUpdateRSSIBlock)block;
- (void)stopReadRSSI;

- (NSString *)hashValue;

- (void)setDidUpdateConnectStateBlock:(DidUpdateConnectStateBlock)block;

- (void)discoverServices:(DidDiscoverServicesBlock)block;
- (void)discoverServiceWithUUID:(CBUUID *)uuid complete:(DidDiscoverSpecialServiceBlock)block;

- (void)discoverCharacteristics:(DidDiscoverCharacteristicsBlock)block;
- (void)discoverCharacteristicsWithUUID:(CBUUID *)uuid forService:(CBService *)service complete:(DidDiscoverSpecialCharacteristicsBlock)block;
- (void)discoverCharacteristicsWithUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID complete:(DidDiscoverSpecialCharacteristicsBlock)block;

- (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic complete:(DidWriteValueForCharacteristicBlock)block;
- (void)writeValue:(NSData *)data forCharacteristicUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID complete:(DidWriteValueForCharacteristicBlock)block;

- (void)readValueForCharacteristic:(CBCharacteristic *)characteristic complete:(DidReadValueForCharacteristicBLock)block;
- (void)readValueForCharacteristicUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID complete:(DidReadValueForCharacteristicBLock)block;

- (void)notify:(BOOL)notify forCharacteristicUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID didUpdateBlock:(DidUpdateNotificationStateForCharacteristicBlock)block;

@end
