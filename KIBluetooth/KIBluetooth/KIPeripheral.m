//
//  KIPeripheral.m
//  Kitalker
//
//  Created by Kitalker on 14-1-16.
//  Copyright (c) 2014年 杨 烽. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KIPeripheral.h"

@interface KIPeripheral ()

@property (nonatomic, strong) CBPeripheral  *peripheral;

@property (nonatomic, assign) BOOL      isDiscoverSpecialService;
@property (nonatomic, assign) BOOL      isDidDiscoverSpecialCharacteristics;

@property (nonatomic, copy) DidUpdateConnectStateBlock          didUpdateConnectStateBlock;

@property (nonatomic, copy) DidDiscoverServicesBlock            didDiscoverServicesBlock;
@property (nonatomic, copy) DidDiscoverCharacteristicsBlock     didDiscoverCharacteristicsBlock;

@property (nonatomic, strong) NSMutableArray                    *serviceUUIDList;
@property (nonatomic, assign) BOOL                              isFindService;

@property (nonatomic, strong) NSMutableArray                    *characteristicUUIDList;
@property (nonatomic, assign) BOOL                              isFindCharacteristic;

@property (nonatomic, strong) NSMutableDictionary               *didWriteValueForCharacteristicBlockList;
@property (nonatomic, strong) NSMutableDictionary               *didReadValueForCharacteristicBLockList;

@property (nonatomic, copy) DidUpdateRSSIBlock  didUpdateRSSIBlock;

@property (nonatomic, assign) BOOL              didInvalidateServices;

@property (nonatomic, strong) NSMutableDictionary       *didUpdateNotificationStateForCharacteristicBlockList;

@property (nonatomic, strong) CADisplayLink     *realtimeReadRSSIDisplayLink;

@end

@implementation KIPeripheral

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    NSError *error = [[NSError alloc] initWithDomain:@"main" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
    return error;
}

- (void)dealloc {
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        [self.peripheral removeObserver:self forKeyPath:@"state" context:nil];
    } else {
        [self.peripheral removeObserver:self forKeyPath:@"connected" context:nil];
    }
    
    self.peripheral = nil;
    
    self.advertisementData = nil;
    
    self.didUpdateConnectStateBlock = nil;
    
    self.didDiscoverServicesBlock = nil;
    self.didDiscoverCharacteristicsBlock = nil;
    
    self.serviceUUIDList = nil;
    self.characteristicUUIDList = nil;
    
    self.didWriteValueForCharacteristicBlockList = nil;
    self.didReadValueForCharacteristicBLockList = nil;
    
    self.didUpdateRSSIBlock = nil;
    
    self.didUpdateNotificationStateForCharacteristicBlockList = nil;
    
    [self.realtimeReadRSSIDisplayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    self.realtimeReadRSSIDisplayLink = nil;
}

- (id)initWithPeripheral:(CBPeripheral *)peripheral {
    if (self = [super init]) {
        self.peripheral = peripheral;
        [self.peripheral setDelegate:self];
        
        self.serviceUUIDList = [[NSMutableArray alloc] init];
        self.characteristicUUIDList = [[NSMutableArray alloc] init];
        
        self.didWriteValueForCharacteristicBlockList =[[NSMutableDictionary alloc] init];
        self.didReadValueForCharacteristicBLockList = [[NSMutableDictionary alloc] init];
        
        self.didInvalidateServices = YES;
        
        self.didUpdateNotificationStateForCharacteristicBlockList = [[NSMutableDictionary alloc] init];
        
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
            [self.peripheral addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
        } else {
            [self.peripheral addObserver:self forKeyPath:@"connected" options:NSKeyValueObservingOptionNew context:nil];
        }
    }
    return self;
}

- (CBPeripheral *)peripheral {
    return _peripheral;
}

- (void)readRSSI {
    [self.peripheral readRSSI];
}

- (void)readRSSI:(DidUpdateRSSIBlock)block {
    [self setDidUpdateRSSIBlock:block];
    [self readRSSI];
}

- (void)readRSSIWithRealtime:(BOOL)realtime frameInterval:(NSInteger)frameInterval complete:(DidUpdateRSSIBlock)block {
    
    [self setDidUpdateRSSIBlock:block];
    
    if (self.realtimeReadRSSIDisplayLink != nil) {
        [self.realtimeReadRSSIDisplayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        self.realtimeReadRSSIDisplayLink = nil;
    }
    
    if (realtime == YES) {
        if (self.realtimeReadRSSIDisplayLink == nil) {
            self.realtimeReadRSSIDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(readRSSI)];
            [self.realtimeReadRSSIDisplayLink setFrameInterval:frameInterval];
            [self.realtimeReadRSSIDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        }
    } else {
        [self readRSSI];
    }
}

- (void)stopReadRSSI {
    [self.realtimeReadRSSIDisplayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    self.realtimeReadRSSIDisplayLink = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"state"] || [keyPath isEqualToString:@"connected"]) {
        [self.serviceUUIDList removeAllObjects];
        [self.characteristicUUIDList removeAllObjects];
        
        if (self.didUpdateConnectStateBlock) {
            __weak KIPeripheral *weakSelf = self;
            self.didUpdateConnectStateBlock(weakSelf);
        }
    }
}

- (void)setDidUpdateConnectStateBlock:(DidUpdateConnectStateBlock)block {
    _didUpdateConnectStateBlock = [block copy];
}

#pragma mark ****************************************
#pragma mark 【discoverServices】
#pragma mark ****************************************
- (void)discoverServices:(DidDiscoverServicesBlock)block {
    [self setIsDiscoverSpecialService:NO];
    [self setDidDiscoverServicesBlock:block];
    [self.peripheral setDelegate:self];
    [self.peripheral discoverServices:nil];
}

#define kUUIDKey        @"kUUIDKey"
#define kBlockListKey   @"kBlockListKey"
#define kServiceKey     @"kServiceKey"

- (void)discoverServiceWithUUID:(CBUUID *)uuid complete:(DidDiscoverSpecialServiceBlock)block {
    
    if ([self isConnected] == NO) {
        __weak KIPeripheral *weakSelf = self;
        block(weakSelf, nil, [self errorWithCode:kDisconnectCode message:kDisconnectMsg]);
        return ;
    }
    
    CBService *service = [self findService:uuid];
    if (service) {
        __weak KIPeripheral *weakSelf = self;
        block(weakSelf, service, nil);
        return ;
    }
    
    [self addBlock:block toList:&_serviceUUIDList withUUID:uuid service:nil];
    
    [self discoverNextService];
}

- (void)discoverNextService {
//    if (self.isFindService) {
//        return ;
//    }
    if (self.serviceUUIDList.count == 0) {
        return ;
    }
    
    [self setIsDiscoverSpecialService:YES];
    
    NSMutableDictionary *item = [self.serviceUUIDList firstObject];
    CBUUID *uuid = [item objectForKey:kUUIDKey];
    
#ifdef DEBUG
    NSLog(@"开始查找[Service]: %@", uuid);
#endif
    
    if (uuid) {
        [self setIsFindService:YES];
        [self.peripheral setDelegate:self];
        [self.peripheral discoverServices:@[uuid]];
    }
}

#pragma mark ****************************************
#pragma mark 【discoverCharacteristics】
#pragma mark ****************************************
- (void)discoverCharacteristics:(DidDiscoverCharacteristicsBlock)block {
    NSCParameterAssert(self.peripheral.services != nil);
    [self setIsDidDiscoverSpecialCharacteristics:NO];
    
    [self setDidDiscoverCharacteristicsBlock:block];
    [self.peripheral.services enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self.peripheral setDelegate:self];
        [self.peripheral discoverCharacteristics:nil forService:obj];
    }];
}

- (void)discoverNextCharacteristic {
//    if (self.isFindCharacteristic) {
//        return ;
//    }
    if (self.characteristicUUIDList.count == 0) {
        return ;
    }
    
    [self setIsDidDiscoverSpecialCharacteristics:YES];
    
    NSMutableDictionary *item = [self.characteristicUUIDList firstObject];
    CBUUID *uuid = [item objectForKey:kUUIDKey];
#ifdef DEBUG
    NSLog(@"开始查找[Characteristic]: %@", uuid);
#endif
    if (uuid) {
        [self setIsFindCharacteristic:YES];
        CBService *service = [item objectForKey:kServiceKey];
        [self.peripheral setDelegate:self];
        [self.peripheral discoverCharacteristics:@[uuid] forService:service];
    }
}

- (void)discoverCharacteristicsWithUUID:(CBUUID *)uuid forService:(CBService *)service complete:(DidDiscoverSpecialCharacteristicsBlock)block {
    __weak KIPeripheral *weakSelf = self;
    if ([self isConnected] == NO) {
        block(weakSelf, service, nil, nil);
        return ;
    }
    
    CBCharacteristic *characteristic = [self findCharacteristicWithUUID:uuid forService:service];
    if (characteristic) {
        block(weakSelf, service, characteristic, nil);
        return ;
    }
    
    if (service == nil) {
        block(weakSelf, nil, nil, [self errorWithCode:kFindServiceFailedCode message:kFindServiceFailedMsg]);
        return ;
    }
    
    [self addBlock:block toList:&_characteristicUUIDList withUUID:uuid service:service];
    
    [self discoverNextCharacteristic];
}

- (void)addBlock:(id)block toList:(NSMutableArray * __strong *)list withUUID:(CBUUID *)uuid service:(CBService *)service {
    if (block == nil || uuid == nil) {
        return ;
    }
    
    BOOL has = NO;
    for (NSMutableDictionary *item in *list) {
        CBUUID *aUUID = [item objectForKey:kUUIDKey];
        if ([aUUID.UUIDString isEqualToString:uuid.UUIDString]) {
            has = YES;
            NSMutableArray *blockList = [item objectForKey:kBlockListKey];
            [blockList addObject:block];
            
            if (service) {
                [item setObject:service forKey:kServiceKey];
            }
            break;
        }
    }
    
    if (has == NO) {
        NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
        [item setObject:uuid forKey:kUUIDKey];
        
        NSMutableArray *blockList = [[NSMutableArray alloc] init];
        [blockList addObject:block];
        
        [item setObject:blockList forKey:kBlockListKey];
        
        if (service) {
            [item setObject:service forKey:kServiceKey];
        }
        [*list addObject:item];
    }
}

- (void)discoverCharacteristicsWithUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID complete:(DidDiscoverSpecialCharacteristicsBlock)block {
    CBService *specialService = [self findService:serviceUUID];
    __weak KIPeripheral *weakSelf = self;
    if (specialService == nil) {
        [self discoverServiceWithUUID:serviceUUID complete:^(KIPeripheral *peripheral, CBService *service, NSError *error) {
            if (service) {
                [weakSelf discoverCharacteristicsWithUUID:uuid forService:service complete:^(KIPeripheral *peripheral, CBService *service, CBCharacteristic *characteristic, NSError *error) {
                    block(weakSelf, service, characteristic, error);
                }];
            } else {
                block(weakSelf, service, nil, [weakSelf errorWithCode:kFindServiceFailedCode message:kFindServiceFailedMsg]);
            }
        }];
    } else {
        CBCharacteristic *specialCharacteristic = [self findCharacteristicWithUUID:uuid forService:specialService];
        if (specialCharacteristic == nil) {
            [self discoverCharacteristicsWithUUID:uuid forService:specialService complete:^(KIPeripheral *peripheral, CBService *service, CBCharacteristic *characteristic, NSError *error) {
                block(weakSelf, specialService, characteristic, error);
            }];
        } else {
            block(weakSelf, specialService, specialCharacteristic, nil);
        }
    }
}

- (void)writeValue:(NSData *)data forCharacteristic:(CBCharacteristic *)characteristic complete:(DidWriteValueForCharacteristicBlock)block {
    if (data == nil) {
         __weak KIPeripheral *weakSelf = self;
        block(weakSelf, characteristic.service, characteristic, [self errorWithCode:kWriteValueErrorCode message:kWriteValueErrorMsg]);
    } else if (characteristic != nil) {
        if (block) {
            [self.didWriteValueForCharacteristicBlockList setObject:block forKey:characteristic.UUID.UUIDString];
        }
        [self.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    }
}

- (void)writeValue:(NSData *)data forCharacteristicUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID complete:(DidWriteValueForCharacteristicBlock)block {
    __weak KIPeripheral *weakSelf = self;
    [self discoverCharacteristicsWithUUID:uuid forServiceUUID:serviceUUID complete:^(KIPeripheral *peripheral, CBService *service, CBCharacteristic *characteristic, NSError *error) {
        if (characteristic) {
            [weakSelf writeValue:data forCharacteristic:characteristic complete:block];
        } else {
            block(weakSelf, service, characteristic, error);
        }
    }];
}

- (void)readValueForCharacteristic:(CBCharacteristic *)characteristic complete:(DidReadValueForCharacteristicBLock)block {
    if (characteristic != nil) {
        if (block) {
            [self.didReadValueForCharacteristicBLockList setObject:block forKey:characteristic.UUID.UUIDString];
        }
        [self.peripheral readValueForCharacteristic:characteristic];
    }
}

- (void)readValueForCharacteristicUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID complete:(DidReadValueForCharacteristicBLock)block {
    __weak KIPeripheral *weakSelf = self;
    [self discoverCharacteristicsWithUUID:uuid forServiceUUID:serviceUUID complete:^(KIPeripheral *peripheral, CBService *service, CBCharacteristic *characteristic, NSError *error) {
        if (characteristic) {
            [weakSelf readValueForCharacteristic:characteristic complete:block];
        } else {
            block(weakSelf, service, characteristic, nil, error);
        }
    }];
}

- (void)notify:(BOOL)notify forCharacteristicUUID:(CBUUID *)uuid forServiceUUID:(CBUUID *)serviceUUID didUpdateBlock:(DidUpdateNotificationStateForCharacteristicBlock)block {
    if (uuid == nil || serviceUUID == nil || block == nil) {
        return ;
    }
    
    [self.didUpdateNotificationStateForCharacteristicBlockList setObject:block forKey:[self notifyKey:uuid sUUID:serviceUUID]];
    
    __weak KIPeripheral *weakSelf = self;
    [self discoverCharacteristicsWithUUID:uuid forServiceUUID:serviceUUID complete:^(KIPeripheral *peripheral, CBService *service, CBCharacteristic *characteristic, NSError *error) {
        
        if (service) {
            if (characteristic) {
                [weakSelf.peripheral setNotifyValue:notify forCharacteristic:characteristic];
            } else {
                block(weakSelf, service, characteristic, NO, nil, [weakSelf errorWithCode:kFindCharacteristicsFailedCode message:kFindCharacteristicsFailedMsg]);
            }
        } else {
            block(weakSelf, service, nil, NO, nil, [weakSelf errorWithCode:kFindServiceFailedCode message:kFindServiceFailedMsg]);
        }
    }];
}

- (NSString *)notifyKey:(CBUUID *)cUUID sUUID:(CBUUID *)sUUID {
    NSString *key = [NSString stringWithFormat:@"%@-%@", [sUUID UUIDString], [cUUID UUIDString]];
    return key;
}

- (CBService *)findService:(CBUUID *)uuid {
    CBService *service = nil;
    
    if (self.didInvalidateServices == NO) {
        for (CBService *s in self.peripheral.services) {
            if ([s.UUID.UUIDString isEqualToString:uuid.UUIDString]) {
                service = s;
                break;
            }
        }
    }
    return service;
}

- (CBCharacteristic *)findCharacteristicWithUUID:(CBUUID *)uuid forService:(CBService *)service {
    CBCharacteristic *characteristic = nil;
    if (self.didInvalidateServices == NO) {
        for (CBCharacteristic *c in service.characteristics) {
            if ([c.UUID.UUIDString isEqualToString:uuid.UUIDString]) {
                characteristic = c;
                break;
            }
        }
    }
    return characteristic;
}

- (BOOL)isEqual:(id)object {
    KIPeripheral *p1 = self;
    KIPeripheral *p2 = (KIPeripheral *)object;
    if ([[p1 UUIDString] isEqualToString:[p2 UUIDString]]) {
        return YES;
    }
    return NO;
}

//- (NSString *)description {
//    return self.peripheral.description;
//}

- (NSString *)hashValue {
    return [NSString stringWithFormat:@"%lu", (unsigned long)self.peripheral.hash];
}

#pragma mark ****************************************
#pragma mark 【getter】
#pragma mark ****************************************

- (CFUUIDRef)UUID {
    if ([self.peripheral respondsToSelector:@selector(UUID)]) {
        id uuid = [self.peripheral performSelector:@selector(UUID)];
        return (__bridge CFUUIDRef)(uuid);
    }
    return nil;
}

- (NSUUID *)identifier {
    return self.peripheral.identifier;
}

- (NSString *)UUIDString {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        return self.peripheral.identifier.UUIDString;
    }
    if (self.UUID) {
        CBUUID *tempUUID = [CBUUID UUIDWithCFUUID:self.UUID];
        return tempUUID.UUIDString;
    }
    return nil;
}

- (NSString *)name {
    return self.peripheral.name;
}

- (NSNumber *)RSSI {
    return self.peripheral.RSSI;
}

- (BOOL)isConnected {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        if (self.state == CBPeripheralStateConnected) {
            return YES;
        }
        return NO;
    }
    if ([self.peripheral respondsToSelector:@selector(isConnected)]) {
        BOOL connected = [self.peripheral performSelector:@selector(isConnected)];
        return connected;
    }
    return NO;
}

- (CBPeripheralState)state {
    return self.peripheral.state;
}

- (NSArray *)services {
    return self.peripheral.services;
}

- (NSString *)description {
    return [[super description] stringByAppendingFormat:@"[%@]", self.UUIDString];
}

#pragma mark ****************************************
#pragma mark 【CBPeripheralDelegate】
#pragma mark ****************************************

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
#ifdef DEBUG
    NSLog(@"发现[Services]: %@", peripheral.services);
#endif
    
    __weak KIPeripheral *weakSelf = self;
    
    if (self.isDiscoverSpecialService) {
        
        NSMutableDictionary *firstItem = [self.serviceUUIDList firstObject];
        CBUUID *firstUUID = [firstItem objectForKey:kUUIDKey];
        NSMutableArray *firstBlockList = [firstItem objectForKey:kBlockListKey];
        
        CBService *findService = nil;
        
        for (CBService *service in peripheral.services) {
            if ([service.UUID.UUIDString isEqualToString:firstUUID.UUIDString]) {
                findService = service;
                break;
            }
        }
        
        for (DidDiscoverSpecialServiceBlock block in firstBlockList) {
            block(weakSelf, findService, findService==nil?[self errorWithCode:kFindServiceFailedCode message:kFindServiceFailedMsg]:nil);
        }
        
        if (self.serviceUUIDList.count > 0) {
            [self.serviceUUIDList removeObjectAtIndex:0];
        }
        
        [self setIsFindService:NO];
        [self discoverNextService];
        
    } else {
        if (self.didDiscoverServicesBlock != nil) {
            self.didDiscoverServicesBlock(weakSelf, peripheral.services, error);
        }
    }
    
    self.didInvalidateServices = NO;
}

- (void)peripheralDidInvalidateServices:(CBPeripheral *)peripheral {
    [self peripheral:peripheral didModifyServices:nil];
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray *)invalidatedServices {
    self.didInvalidateServices = YES;
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
#ifdef DEBUG
    NSLog(@"发现[Characteristics] %@", service.characteristics);
#endif
    __weak KIPeripheral *weakSelf = self;
    
    if (self.isDidDiscoverSpecialCharacteristics) {
        NSMutableDictionary *firstItem = [self.characteristicUUIDList firstObject];
        CBUUID *firstUUID = [firstItem objectForKey:kUUIDKey];
        NSMutableArray *firstBlockList = [firstItem objectForKey:kBlockListKey];
        
        CBCharacteristic *findCharacteristic = nil;
        
        for (CBCharacteristic *c in service.characteristics) {
            if ([c.UUID.UUIDString isEqualToString:firstUUID.UUIDString]) {
                findCharacteristic = c;
                break;
            }
        }
        
        for (DidDiscoverSpecialCharacteristicsBlock block in firstBlockList) {
            block(weakSelf, service, findCharacteristic, findCharacteristic==nil?[self errorWithCode:kFindCharacteristicsFailedCode message:kFindCharacteristicsFailedMsg]:nil);
        }
        
        if (self.characteristicUUIDList.count > 0) {
            [self.characteristicUUIDList removeObjectAtIndex:0];
        }
        
        [self setIsFindCharacteristic:NO];
        [self discoverNextCharacteristic];
        
    } else {
        if (self.didDiscoverCharacteristicsBlock != nil) {
            self.didDiscoverCharacteristicsBlock(weakSelf, service, service.characteristics, error);
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    __weak KIPeripheral *weakSelf = self;
    DidReadValueForCharacteristicBLock block = [self.didReadValueForCharacteristicBLockList objectForKey:characteristic.UUID.UUIDString];
    if (block) {
        block(weakSelf, characteristic.service, characteristic, characteristic.value, error);
    }
    
    NSString *key = [self notifyKey:characteristic.UUID sUUID:characteristic.service.UUID];
    DidUpdateNotificationStateForCharacteristicBlock notifyBlock = [self.didUpdateNotificationStateForCharacteristicBlockList objectForKey:key];
    if (notifyBlock) {
        notifyBlock(weakSelf, characteristic.service, characteristic, NO, characteristic.value, error);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    DidWriteValueForCharacteristicBlock block = [self.didWriteValueForCharacteristicBlockList objectForKey:characteristic.UUID.UUIDString];
    if (block != nil) {
        __weak KIPeripheral *weakSelf = self;
        block(weakSelf, characteristic.service, characteristic, error);
    }
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error {
    if (self.didUpdateRSSIBlock) {
        __weak KIPeripheral *weakSelf = self;
        self.didUpdateRSSIBlock(weakSelf, peripheral.RSSI, error);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
#ifdef DEBUG
    NSLog(@"didUpdateNotificationStateForCharacteristic %@:%@", characteristic.UUIDString, characteristic.isNotifying?@"YES":@"NO");
#endif
    NSString *key = [self notifyKey:characteristic.UUID sUUID:characteristic.service.UUID];
    DidUpdateNotificationStateForCharacteristicBlock block = [self.didUpdateNotificationStateForCharacteristicBlockList objectForKey:key];
    if (block) {
        __weak KIPeripheral *weakSelf = self;
        block(weakSelf, characteristic.service, characteristic, YES, characteristic.value, error);
    }
}

@end
