//
//  KIBluePeripheralManager.h
//  Kitalker
//
//  Created by Kitalker on 14-1-17.
//  Copyright (c) 2014年 杨 烽. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "KIPeripheral.h"
#import "CBUUID+KIAdditions.h"

@class KIBluePeripheralManager;

typedef enum {
    PMRequestTypeRead,
    PMRequestTypeWrite,
} PMRequestType;

typedef void(^PMDidStartAdvertisingBlock)   (KIBluePeripheralManager *peripheralManager, NSError *error);
typedef void(^PMDidStopAdvertisingBlock)    (KIBluePeripheralManager *peripheralManager);
typedef void(^PMDidUpdateStateBlock)        (KIBluePeripheralManager *peripheralManager, CBPeripheralManagerState state);
typedef void(^PMDidAddServiceBlock)         (KIBluePeripheralManager *peripheralManager, CBService *service, NSError *error);

typedef void(^PMDidSubscribeToCharacteristicBlock)      (KIBluePeripheralManager *peripheralManager, CBCentral *central, CBCharacteristic *characteristic);
typedef void(^PMDidUnsubscribeFromCharacteristicBlock)  (KIBluePeripheralManager *peripheralManager, CBCentral *central, CBCharacteristic *characteristic);

typedef void(^PMDidReceiveWriteRequestsBlock)   (KIBluePeripheralManager *peripheralManager, NSArray *requests);
typedef void(^PMDidReceiveReadRequestBlock)     (KIBluePeripheralManager *peripheralManager, CBATTRequest *request);

typedef void(^PMDidReceiveRequestBlock)         (KIBluePeripheralManager *peripheralManager, NSArray *requests, NSData *value, PMRequestType type);


@interface KIBluePeripheralManager : NSObject <CBPeripheralManagerDelegate>

@property(readonly) CBPeripheralManagerState state;

@property(readonly) BOOL isAdvertising;

+ (KIBluePeripheralManager *)sharedInstance;

- (void)startAdvertising:(NSDictionary *)advertisementData complete:(PMDidStartAdvertisingBlock)block;

- (void)stopAdvertising:(PMDidStopAdvertisingBlock)block;

- (void)addService:(CBMutableService *)service complete:(PMDidAddServiceBlock)block;

- (void)removeService:(CBMutableService *)service;

- (void)removeServiceWithUUID:(CBUUID *)serviceUUID;

- (void)removeAllServices;

- (NSArray *)centralList;

- (BOOL)updateValue:(NSData *)value forCharacteristic:(CBMutableCharacteristic *)characteristic onSubscribedCentrals:(NSArray *)centrals;

- (BOOL)updateValue:(NSData *)value forCharacteristic:(CBMutableCharacteristic *)characteristic onCentral:(CBCentral *)central;
- (BOOL)updateValue:(NSData *)value forCharacteristic:(CBMutableCharacteristic *)characteristic;

- (BOOL)updateValue:(NSData *)value forCharacteristicUUID:(CBUUID *)uuid onCentral:(CBCentral *)central;
- (BOOL)updateValue:(NSData *)value forCharacteristicUUID:(CBUUID *)uuid onCentralUUID:(CBUUID *)centralUUID;
- (BOOL)updateValue:(NSData *)value forCharacteristicUUID:(CBUUID *)uuid;

- (BOOL)updateValue:(NSData *)value forCharacteristicUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID onCentralUUID:(CBUUID *)centralUUID;
- (BOOL)updateValue:(NSData *)value forCharacteristicUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID;


- (void)setDidUpdateStateBlock:(PMDidUpdateStateBlock)block;

- (void)setDidSubscribeToCharacteristicBlock:(PMDidSubscribeToCharacteristicBlock)block;
- (void)setDidUnsubscribeFromCharacteristicBlock:(PMDidUnsubscribeFromCharacteristicBlock)block;

- (void)setDidReceiveWriteRequestsBlock:(PMDidReceiveWriteRequestsBlock)block;
- (void)setDidReceiveReadRequestBlock:(PMDidReceiveReadRequestBlock)block;

- (void)setRequestHandlerWithServiceUUID:(CBUUID *)sUUID cUUID:(CBUUID *)cUUID block:(PMDidReceiveRequestBlock)block;

- (void)respondToRequest:(CBATTRequest *)request withResult:(CBATTError)result;
- (void)respondToRequests:(NSArray *)requests withResult:(CBATTError)result;
- (void)respondSuccessToRequest:(NSArray *)requests;

@end
