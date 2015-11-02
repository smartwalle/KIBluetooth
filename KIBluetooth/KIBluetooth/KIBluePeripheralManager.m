//
//  KIBluePeripheralManager.m
//  BlueTooth
//
//  Created by Dev on 14-1-17.
//  Copyright (c) 2014年 smartwalle. All rights reserved.
//

#import "KIBluePeripheralManager.h"

@interface KIBluePeripheralManager ()

@property (nonatomic, strong) CBPeripheralManager   *peripheralManager;

@property (nonatomic, strong) NSMutableDictionary   *centralDictionary;
@property (nonatomic, strong) NSMutableDictionary   *serviceList;

@property (nonatomic, copy) PMDidStartAdvertisingBlock  didStartAdvertisingBlock;
@property (nonatomic, copy) PMDidUpdateStateBlock       didUpdateStateBlock;


@property (nonatomic, copy) PMDidSubscribeToCharacteristicBlock     didSubscribeToCharacteristicBlock;
@property (nonatomic, copy) PMDidUnsubscribeFromCharacteristicBlock didUnsubscribeFromCharacteristicBlock;


@property (nonatomic, copy) PMDidReceiveWriteRequestsBlock  didReceiveWriteRequestsBlock;
@property (nonatomic, copy) PMDidReceiveReadRequestBlock    didReceiveReadRequestBlock;

@property (nonatomic, strong) NSMutableDictionary   *addServiceBlockList;
@property (nonatomic, strong) NSMutableDictionary   *receiveRequestsBlockList;

@end

@implementation KIBluePeripheralManager

static KIBluePeripheralManager  *BLUE_PERIPHERIAL_MANAGER = nil;

+ (KIBluePeripheralManager *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BLUE_PERIPHERIAL_MANAGER = [[super allocWithZone:nil] init];
    });
    return BLUE_PERIPHERIAL_MANAGER;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (void)dealloc {
    [self.peripheralManager setDelegate:nil];
    self.peripheralManager = nil;
    
    self.centralDictionary = nil;
    self.serviceList = nil;
    
    self.didStartAdvertisingBlock = nil;
    self.didUpdateStateBlock = nil;
    
    self.didSubscribeToCharacteristicBlock = nil;
    self.didUnsubscribeFromCharacteristicBlock = nil;
    
    self.didReceiveWriteRequestsBlock = nil;
    self.didReceiveReadRequestBlock = nil;
    
    self.addServiceBlockList = nil;
    self.receiveRequestsBlockList = nil;
}

- (id)init {
    if (BLUE_PERIPHERIAL_MANAGER == nil) {
        if (self = [super init]) {
            BLUE_PERIPHERIAL_MANAGER = self;
            [self setup];
        }
    }
    return BLUE_PERIPHERIAL_MANAGER;
}

- (BOOL)isAdvertising {
    return self.peripheralManager.isAdvertising;
}

- (CBPeripheralManagerState)state {
    return self.peripheralManager.state;
}

- (void)setup {
    if (self.peripheralManager == nil) {
        self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
        
        self.centralDictionary = [[NSMutableDictionary alloc] init];
        self.serviceList = [[NSMutableDictionary alloc] init];
        
        self.addServiceBlockList = [[NSMutableDictionary alloc] init];
        self.receiveRequestsBlockList = [[NSMutableDictionary alloc] init];
    }
}

- (void)startAdvertising:(NSDictionary *)advertisementData complete:(PMDidStartAdvertisingBlock)block {
    [self setDidStartAdvertisingBlock:block];
    [self.peripheralManager startAdvertising:advertisementData];
}

- (void)stopAdvertising:(PMDidStopAdvertisingBlock)block {
    [self.peripheralManager stopAdvertising];
    if(block != nil) {
        __weak KIBluePeripheralManager *weakSelf = self;
        block(weakSelf);
    }
}

- (void)addService:(CBMutableService *)service complete:(PMDidAddServiceBlock)block {
    if (service == nil) {
        return;
    }
    
    if (block) {
        [self.addServiceBlockList setObject:block forKey:service.UUID.UUIDString];
    }
    [self.peripheralManager addService:service];
    [self.serviceList setObject:service forKey:service.UUIDString];
}

- (void)removeService:(CBMutableService *)service {
    [self.peripheralManager removeService:service];
    [self removeServiceWithUUID:service.UUID];
}

- (void)removeServiceWithUUID:(CBUUID *)serviceUUI {
    [self.serviceList removeObjectForKey:serviceUUI.UUIDString];
}

- (void)removeAllServices {
    [self.peripheralManager removeAllServices];
    [self.serviceList removeAllObjects];
}

- (NSArray *)centralList {
    return [self.centralDictionary allValues];
}

- (BOOL)updateValue:(NSData *)value forCharacteristic:(CBMutableCharacteristic *)characteristic onSubscribedCentrals:(NSArray *)centrals {
    NSAssert(characteristic != nil, @"characteristic 不能为 nil");
    return [self.peripheralManager updateValue:value forCharacteristic:characteristic onSubscribedCentrals:centrals];
}

- (BOOL)updateValue:(NSData *)value forCharacteristic:(CBMutableCharacteristic *)characteristic onCentral:(CBCentral *)central {
    NSArray *cList = nil;
    if (central) {
        cList = @[central];
    }
    return [self updateValue:value forCharacteristic:characteristic onSubscribedCentrals:cList];
}

- (BOOL)updateValue:(NSData *)value forCharacteristic:(CBMutableCharacteristic *)characteristic {
    return [self updateValue:value forCharacteristic:characteristic onSubscribedCentrals:nil];
}

- (BOOL)updateValue:(NSData *)value forCharacteristicUUID:(CBUUID *)uuid onCentral:(CBCentral *)central {
    NSArray *sList = [self.serviceList allValues];
    BOOL find = NO;
    for (CBService *s in sList) {
        for (CBMutableCharacteristic *c in s.characteristics) {
            if ([c.UUIDString isEqualToString:uuid.UUIDString]) {
                find = [self updateValue:value forCharacteristic:c onCentral:central];
            }
        }
    }
    return find;
}

- (BOOL)updateValue:(NSData *)value forCharacteristicUUID:(CBUUID *)uuid onCentralUUID:(CBUUID *)centralUUID {
    CBCentral *central = [self.centralDictionary objectForKey:centralUUID.UUIDString];
    return [self updateValue:value forCharacteristicUUID:uuid onCentral:central];
}

- (BOOL)updateValue:(NSData *)value forCharacteristicUUID:(CBUUID *)uuid {
    return [self updateValue:value forCharacteristicUUID:uuid onCentralUUID:nil];
}

- (BOOL)updateValue:(NSData *)value forCharacteristicUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID onCentralUUID:(CBUUID *)centralUUID {
    CBCentral *cetral = [self.centralDictionary objectForKey:centralUUID.UUIDString];
    
    CBService *s = [self.serviceList objectForKey:serviceUUID.UUIDString];
    for (CBMutableCharacteristic *c in s.characteristics) {
        if ([c.UUIDString isEqualToString:uuid.UUIDString]) {
            return [self updateValue:value forCharacteristic:c onCentral:cetral];
        }
    }
    return NO;
}

- (BOOL)updateValue:(NSData *)value forCharacteristicUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID {
    return [self updateValue:value forCharacteristicUUID:uuid forServiceUUID:serviceUUID onCentralUUID:nil];
}

#pragma mark ****************************************
#pragma mark 【Block setter】
#pragma mark ****************************************

- (void)setDidUpdateStateBlock:(PMDidUpdateStateBlock)block {
    _didUpdateStateBlock = [block copy];
}

- (void)setDidSubscribeToCharacteristicBlock:(PMDidSubscribeToCharacteristicBlock)block {
    _didSubscribeToCharacteristicBlock = [block copy];
}

- (void)setDidUnsubscribeFromCharacteristicBlock:(PMDidUnsubscribeFromCharacteristicBlock)block {
    _didUnsubscribeFromCharacteristicBlock = [block copy];
}

- (void)setDidReceiveWriteRequestsBlock:(PMDidReceiveWriteRequestsBlock)block {
    _didReceiveWriteRequestsBlock = [block copy];
}

- (void)setDidReceiveReadRequestBlock:(PMDidReceiveReadRequestBlock)block {
    _didReceiveReadRequestBlock = [block copy];
}

- (void)setRequestHandlerWithServiceUUID:(CBUUID *)sUUID cUUID:(CBUUID *)cUUID block:(PMDidReceiveRequestBlock)block {
    if (block == nil) {
        return ;
    }
    
    NSString *key = [self keyWithSUUID:sUUID.UUIDString cUUID:cUUID.UUIDString];
    [self.receiveRequestsBlockList setObject:block forKey:key];
}

- (NSString *)keyWithSUUID:(NSString *)sUUID cUUID:(NSString *)cUUID {
    NSString *key = [NSString stringWithFormat:@"%@-%@", sUUID, cUUID];
    return key;
}

#pragma mark ****************************************
#pragma mark 【CBPeripheralManagerDelegate】
#pragma mark ****************************************

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if (self.didUpdateStateBlock) {
        __weak KIBluePeripheralManager *weakSelf = self;
        self.didUpdateStateBlock(weakSelf, peripheral.state);
    }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
    if (self.didStartAdvertisingBlock != nil) {
        __weak KIBluePeripheralManager *weakSelf = self;
        self.didStartAdvertisingBlock(weakSelf, error);
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
    PMDidAddServiceBlock block = [self.addServiceBlockList objectForKey:service.UUID.UUIDString];
    if (block) {
        __weak KIBluePeripheralManager *weakSelf = self;
        block(weakSelf, service, error);
        [self.addServiceBlockList removeObjectForKey:service.UUID.UUIDString];
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    [self.centralDictionary setObject:central forKey:central.UUIDString];
    if (self.didSubscribeToCharacteristicBlock) {
        __weak KIBluePeripheralManager *weakSelf = self;
        self.didSubscribeToCharacteristicBlock(weakSelf, central, characteristic);
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    [self.centralDictionary removeObjectForKey:central.UUIDString];
    if (self.didUnsubscribeFromCharacteristicBlock) {
        __weak KIBluePeripheralManager *weakSelf = self;
        self.didUnsubscribeFromCharacteristicBlock(weakSelf, central, characteristic);
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request {
    if (request == nil) {
        return ;
    }
#ifdef DEBUG
    NSLog(@"ReceiveReadRequest: central[%@] service[%@] characteristic[%@]", request.central.UUIDString, request.characteristic.service.UUIDString, request.characteristic.UUIDString);
#endif
    [self respondToRequest:@[request] value:nil type:PMRequestTypeRead];
    
    if (self.didReceiveReadRequestBlock) {
        __weak KIBluePeripheralManager *weakSelf = self;
        self.didReceiveReadRequestBlock(weakSelf, request);
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests {
    __block CBATTRequest *request = nil;
    NSMutableData *value = [[NSMutableData alloc] init];
    
    [requests enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (idx == 0) {
            request = obj;
        }
        [value appendData:[(CBATTRequest *)obj value]];
    }];
    [self respondToRequest:requests value:value type:PMRequestTypeWrite];
#ifdef DEBUG
    NSLog(@"ReceiveWriteRequest: central[%@] service[%@] characteristic[%@]", request.central.UUIDString, request.characteristic.service.UUIDString, request.characteristic.UUIDString);
#endif
    
    if (self.didReceiveWriteRequestsBlock != nil) {
        __weak KIBluePeripheralManager *weakSelf = self;
        self.didReceiveWriteRequestsBlock(weakSelf, requests);
    }
}

- (void)respondToRequest:(NSArray *)requests value:(NSData *)value type:(PMRequestType)type {
    if (requests.count == 0) {
        return ;
    }
    CBATTRequest *request = requests[0];
    
    CBCharacteristic *c = request.characteristic;
    CBService *s = c.service;
    
    NSString *key = [self keyWithSUUID:s.UUIDString cUUID:c.UUIDString];
    PMDidReceiveRequestBlock block = [self.receiveRequestsBlockList objectForKey:key];
    
    if (block) {
        __weak KIBluePeripheralManager *weakSelf = self;
        block(weakSelf, requests, value, type);
    }
}

- (void)respondToRequest:(CBATTRequest *)request withResult:(CBATTError)result {
    [self.peripheralManager respondToRequest:request withResult:result];
}

- (void)respondToRequests:(NSArray *)requests withResult:(CBATTError)result {
    [requests enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self.peripheralManager respondToRequest:obj withResult:result];
    }];
}

- (void)respondSuccessToRequest:(NSArray *)requests {
    [self respondToRequests:requests withResult:CBATTErrorSuccess];
}

@end
