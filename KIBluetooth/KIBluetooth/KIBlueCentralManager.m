//
//  KIBlueCentralManager.m
//  Kitalker
//
//  Created by Kitalker on 14-1-16.
//  Copyright (c) 2014年 杨 烽. All rights reserved.
//

#import "KIBlueCentralManager.h"

NSString * const CMDidStartScanNotification             = @"CMDidStartScanNotification";
NSString * const CMDidStopScanNotification              = @"CMDidStopScanNotification";
NSString * const CMDidUpdateStateNotification           = @"CMDidUpdateStateNotification";
NSString * const CMDidDiscoverPeripheralNotification    = @"CMDidDiscoverPeripheralNotification";
NSString * const CMDidConnectPeripheralNotification     = @"CMDidConnectPeripheralNotification";
NSString * const CMDidDisconnectPeripheralNotification  = @"CMDidDisconnectPeripheralNotification";

@interface KIBlueCentralManager ()

@property (nonatomic, strong) CBCentralManager          *centralManager;
@property (nonatomic, strong) NSMutableArray            *peripheralList;

@property (nonatomic, strong) dispatch_queue_t          connectQueue;

@property (nonatomic, assign) BOOL                      isConnecting;
@property (nonatomic, strong) NSMutableArray            *connectQueueList;

@property (nonatomic, copy) CMDidUpdateStateBlock           didUpdateStateBlock;
@property (nonatomic, copy) CMDidDiscoverPeripheralBlock    didDiscoverPeripheralBlock;
@property (nonatomic, copy) CMDidDisconnectPeripheralBlock  didDisconnectPeripheralBlock;
@property (nonatomic, copy) CMPeripheralFilterBlock         peripheralFilterBlock;
@end


@implementation KIBlueCentralManager

static KIBlueCentralManager *BLUE_CNETRAL_MANAGER  = nil;

+ (KIBlueCentralManager *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BLUE_CNETRAL_MANAGER = [[super allocWithZone:nil] init];
    });
    return BLUE_CNETRAL_MANAGER;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (void)dealloc {
    
    [self.centralManager setDelegate:nil];
    self.centralManager = nil;
    self.peripheralList = nil;
    
    self.connectQueueList = nil;
    
    self.didUpdateStateBlock = nil;
    self.didDiscoverPeripheralBlock = nil;
    self.didDisconnectPeripheralBlock = nil;
    self.peripheralFilterBlock = nil;
}

- (id)init {
    if (BLUE_CNETRAL_MANAGER == nil) {
        if (self = [super init]) {
            BLUE_CNETRAL_MANAGER = self;
            [self setup];
        }
    }
    return BLUE_CNETRAL_MANAGER;
}

- (CBCentralManagerState)state {
    return self.centralManager.state;
}

- (void)setup {
    if (self.centralManager == nil) {
        self.peripheralList = [[NSMutableArray alloc] init];
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        self.connectQueue  = dispatch_queue_create("BLECentralConnectQueue", DISPATCH_QUEUE_SERIAL);
        self.connectQueueList = [[NSMutableArray alloc] init];
    }
}

- (void)startScan:(CMDidStartScanBlock)block {
    [self startScanAllowDuplicatesKey:NO block:block];
}

- (void)startScanAllowDuplicatesKey:(BOOL)allowDuplicatesKey block:(CMDidStartScanBlock)block {
    [self startScanWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@(allowDuplicatesKey)} block:block];
}

- (void)startScanWithServices:(NSArray<CBUUID *> *)serviceUUIDs options:(NSDictionary *)options block:(CMDidStartScanBlock)block {
    
    [self.connectQueueList removeAllObjects];
    [self setIsConnecting:NO];
    
    [self.centralManager stopScan];
    
    [self.centralManager scanForPeripheralsWithServices:serviceUUIDs options:options];
    
    if (block != nil) {
        __weak KIBlueCentralManager *weakSelf = self;
        block(weakSelf);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CMDidStartScanNotification object:nil];
}

- (void)stopScan:(CMDidStopScanBlock)block {
    [self.centralManager stopScan];
    
    if (block != nil) {
        __weak KIBlueCentralManager *weakSelf = self;
        block(weakSelf);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CMDidStopScanNotification object:nil];
}

- (NSArray *)peripherals {
    return _peripheralList;
}

- (void)setPeripheralFilterBlock:(CMPeripheralFilterBlock)block {
    _peripheralFilterBlock = [block copy];
}

- (void)removeAllPeripherals {
    [self disconnectAll];
    [self.peripheralList removeAllObjects];
}

- (void)removeAllDisconnectPeripherals {
    @synchronized(self.peripheralList) {
        for (int i=(int)self.peripheralList.count-1; i>=0; i--) {
            KIPeripheral *p = [self.peripheralList objectAtIndex:i];
            if (![p isConnected]) {
                [self.peripheralList removeObjectAtIndex:i];
            }
        }
    }
}

- (void)disconnect:(KIPeripheral *)peripheral {
    if (peripheral != nil && peripheral.peripheral != nil) {
        [self.centralManager cancelPeripheralConnection:peripheral.peripheral];
    }
}

- (void)disconnectAll {
    for (KIPeripheral *p in self.peripheralList) {
        if ([p isConnected]) {
            [self disconnect:p];
        }
    }
}

#define kPeripheralKey  @"kPeripheralKey"
#define kBlockKey       @"kBlockKey"
#define kTimeoutKey     @"kTimeoutKey"
#define kOptionsKey     @"kOptionsKey"
#define kConnectingKey  @"kConnectingKey"

- (void)cancelConnect:(KIPeripheral *)peripheral {
    if (peripheral != nil && peripheral.peripheral != nil) {
        [self.centralManager cancelPeripheralConnection:peripheral.peripheral];
        
        NSMutableArray *connectedItems = [[NSMutableArray alloc] init];
        
        for (NSDictionary *item in self.connectQueueList) {
            KIPeripheral *p = [item objectForKey:kPeripheralKey];
            NSInteger timeout = [[item objectForKey:kTimeoutKey] integerValue];
            
            if ([p isEqual:peripheral] && timeout <= 0) {
                [connectedItems addObject:item];
            }
        }
        
        [self.connectQueueList removeObjectsInArray:connectedItems];
        
        [self setIsConnecting:NO];
    }
}

- (void)connect:(KIPeripheral *)peripheral
        timeout:(NSInteger)timeout
       complete:(CMDidConnectPeripheralBlock)block {
    [self connect:peripheral options:nil timeout:timeout complete:block];
}

- (void)connect:(KIPeripheral *)peripheral
        options:(NSDictionary *)options
        timeout:(NSInteger)timeout
       complete:(CMDidConnectPeripheralBlock)block {
    [self addDidConnectPeripheral:peripheral options:options timeout:timeout block:block];
}

- (void)connectNextPeripheral {
    if (self.isConnecting) {
        return;
    }
    
    NSMutableDictionary *item = [self.connectQueueList firstObject];
    BOOL isConnecting = [[item objectForKey:kConnectingKey] boolValue];
    
    if (isConnecting) {
        item = nil;
        for (NSMutableDictionary *nextItem in self.connectQueueList) {
            isConnecting = [[nextItem objectForKey:kConnectingKey] boolValue];
            if (!isConnecting) {
                item = nextItem;
            }
        }
    }
    
    if (item) {
        [self setIsConnecting:YES];
        
        KIPeripheral *peripheral = [item objectForKey:kPeripheralKey];
        NSInteger timeout = [[item objectForKey:kTimeoutKey] integerValue];
        NSDictionary *options = [item objectForKey:kOptionsKey];
        
        
        __weak KIBlueCentralManager *weakSelf = self;
        
        dispatch_async(self.connectQueue, ^{
            [weakSelf.centralManager connectPeripheral:peripheral.peripheral options:options];
            [item setObject:[NSNumber numberWithBool:YES] forKey:kConnectingKey];
            if (timeout <= 0) {
                [weakSelf setIsConnecting:NO];
                return ;
            }
            
            double delayInSeconds = timeout;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                NSError *error = [[NSError alloc] initWithDomain:@"main" code:kConnectTimeoutCode userInfo:@{NSLocalizedDescriptionKey:kConnectTimeoutMsg}];
                
                if ([peripheral isConnected] == NO) {
                    [weakSelf.centralManager cancelPeripheralConnection:peripheral.peripheral];
                    [weakSelf didConnectPeripheral:peripheral error:error];
#ifdef DEBUG
                    NSLog(@"Connect Timeout");
#endif
                }
            });
        });
    }
}

- (void)connectWithPeripherls:(NSArray *)peripherals
                      timeout:(NSInteger)timeout
                     complete:(CMDidConnectPeripheralsBlock)block {
    
    [self connectWithPeripherls:peripherals options:nil timeout:timeout complete:block];
}

- (void)connectWithPeripherls:(NSArray *)peripherals
                      options:(NSDictionary *)options
                      timeout:(NSInteger)timeout
                     complete:(CMDidConnectPeripheralsBlock)block {
    __weak KIBlueCentralManager *weakSelf = self;
    
    for (KIPeripheral *p in peripherals) {
        [self addDidConnectPeripheral:p options:options timeout:timeout block:^(KIBlueCentralManager *centralManager, KIPeripheral *peripheral, NSError *error) {
            BOOL finished = (peripherals.lastObject == p)?YES:NO;
            block(weakSelf, peripheral, error, finished);
        }];
    }
}

- (void)addDidConnectPeripheral:(KIPeripheral *)peripheral options:(NSDictionary *)options timeout:(NSUInteger)timeout block:(CMDidConnectPeripheralBlock)block {
    if (peripheral == nil) {
        return ;
    }
    
    if ([peripheral isConnected]) {
        __weak KIBlueCentralManager *weakSelf = self;
        block(weakSelf, peripheral, nil);
        return ;
    }
    
    NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
    [item setObject:peripheral forKey:kPeripheralKey];
    if (block) {
        [item setObject:block forKey:kBlockKey];
    }
    if (options) {
        [item setObject:options forKey:kOptionsKey];
    }
    [item setObject:[NSNumber numberWithInteger:timeout] forKey:kTimeoutKey];
    [self.connectQueueList addObject:item];
    
    [self connectNextPeripheral];
}

- (void)didConnectPeripheral:(KIPeripheral *)peripheral error:(NSError *)error {
    
    [self setIsConnecting:NO];
    
//    NSMutableDictionary *item = [self.connectQueueList firstObject];
//    
//    KIPeripheral *p = [item objectForKey:kPeripheralKey];
//    CMDidConnectPeripheralBlock block = [item objectForKey:kBlockKey];
//    
//    if ([p isEqual:peripheral]) {
//        if (block) {
//            __weak KIBlueCentralManager *weakSelf = self;
//            block(weakSelf, peripheral, error);
//        }
//        
//        [[NSNotificationCenter defaultCenter] postNotificationName:CMDidConnectPeripheralNotification
//                                                            object:nil
//                                                          userInfo:@{@"peripheral": peripheral}];
//        
//        [self.connectQueueList removeObjectAtIndex:0];
//        
//        [self connectNextPeripheral];
//    }
    
    NSMutableArray *connectedItems = [[NSMutableArray alloc] init];
    
    for (NSDictionary *item in self.connectQueueList) {
        KIPeripheral *p = [item objectForKey:kPeripheralKey];
        CMDidConnectPeripheralBlock block = [item objectForKey:kBlockKey];
        
        if ([p isEqual:peripheral]) {
            [connectedItems addObject:item];
            if (block) {
                __weak KIBlueCentralManager *weakSelf = self;
                block(weakSelf, peripheral, error);
            }
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CMDidConnectPeripheralNotification
                                                        object:nil
                                                      userInfo:@{@"peripheral": peripheral}];
    
//    [self.connectQueueList removeObjectAtIndex:0];
    [self.connectQueueList removeObjectsInArray:connectedItems];
    
    [self connectNextPeripheral];
}

#pragma mark ****************************************
#pragma mark 【Block setter】
#pragma mark ****************************************

- (void)setDidUpdateStateBlock:(CMDidUpdateStateBlock)block {
    _didUpdateStateBlock = [block copy];
}

- (void)setDidDiscoverPeripheralBlock:(CMDidDiscoverPeripheralBlock)block {
    _didDiscoverPeripheralBlock = [block copy];
}

- (void)setDidDisconnectPeripheralBlock:(CMDidDisconnectPeripheralBlock)block {
    _didDisconnectPeripheralBlock = [block copy];
}


#pragma mark ****************************************
#pragma mark 【CBPeripheral】
#pragma mark ****************************************

- (BOOL)hasPeripheral:(CBPeripheral *)peripheral {
    for (KIPeripheral *p in self.peripheralList) {
        if (p.peripheral == peripheral) {
            return YES;
        }
    }
    return NO;
}

- (KIPeripheral *)getPeripheral:(CBPeripheral *)peripheral {
    for (KIPeripheral *p in self.peripheralList) {
        if (p.peripheral == peripheral) {
            return p;
        }
    }
    return [[KIPeripheral alloc] initWithPeripheral:peripheral];
}

- (void)addPeripheral:(KIPeripheral *)peripheral {
    if (![self.peripheralList containsObject:peripheral]) {
        [self.peripheralList addObject:peripheral];
    }
}

- (void)removePeripheral:(KIPeripheral *)peripheral {
    @synchronized(self.peripheralList) {
        if ([self.peripheralList containsObject:peripheral]) {
            [self.peripheralList removeObject:peripheral];
        }
    }
}

#pragma mark ****************************************
#pragma mark 【CBCentralManagerDelegate】
#pragma mark ****************************************

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (self.didUpdateStateBlock != nil) {
        __weak KIBlueCentralManager *weakSelf = self;
        self.didUpdateStateBlock(weakSelf, central.state);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:CMDidUpdateStateNotification object:nil];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    if (self.peripheralFilterBlock != nil) {
        if (self.peripheralFilterBlock(self, peripheral, advertisementData) == NO) {
            return ;
        }
    }
    
    KIPeripheral *newPeripheral = [self getPeripheral:peripheral];
    [newPeripheral setAdvertisementData:advertisementData];
    [self addPeripheral:newPeripheral];
#ifdef DEBUG
    NSLog(@"Discover peripheral: %@, advertisementData: %@", newPeripheral, advertisementData);
#endif
    if (self.didDiscoverPeripheralBlock != nil) {
        __weak KIBlueCentralManager *weakSelf = self;
        self.didDiscoverPeripheralBlock(weakSelf, newPeripheral);
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CMDidDiscoverPeripheralNotification
                                                        object:nil
                                                      userInfo:@{@"peripheral": newPeripheral}];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    KIPeripheral *newPeripheral = [self getPeripheral:peripheral];
#ifdef DEBUG
    NSLog(@"Connect peripheral: %@", newPeripheral);
#endif
    [self didConnectPeripheral:newPeripheral error:nil];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    KIPeripheral *newPeripheral = [self getPeripheral:peripheral];
#ifdef DEBUG
    NSLog(@"Fail to connect: %@", [error description]);
#endif
    [self didConnectPeripheral:newPeripheral error:error];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    KIPeripheral *newPeripheral = [self getPeripheral:peripheral];
#ifdef DEBUG
    NSLog(@"Disconnect: %@ Error: %@", newPeripheral, [error description]);
#endif
    
    //如果error不为nil，则表示为异常断开连接，即为非调用cancelPeripheralConnection:断开连接
//    if (error != nil) {
//        [self removePeripheral:newPeripheral];
//    }
    
    if (self.didDisconnectPeripheralBlock != nil) {
        __weak KIBlueCentralManager *weakSelf = self;
        self.didDisconnectPeripheralBlock(weakSelf, newPeripheral, error);
    }
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    if (newPeripheral != nil) {
        [userInfo setObject:newPeripheral forKey:@"peripheral"];
    }
    if (error != nil) {
        [userInfo setObject:error forKey:@"error"];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CMDidDisconnectPeripheralNotification
                                                        object:nil
                                                      userInfo:userInfo];
}

@end
