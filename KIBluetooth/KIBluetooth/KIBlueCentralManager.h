//
//  KIBlueCentralManager.h
//  Kitalker
//
//  Created by Kitalker on 14-1-16.
//  Copyright (c) 2014年 杨 烽. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "KIPeripheral.h"

extern NSString * const CMDidStartScanNotification;
extern NSString * const CMDidStopScanNotification;
extern NSString * const CMDidUpdateStateNotification;
extern NSString * const CMDidDiscoverPeripheralNotification;
extern NSString * const CMDidConnectPeripheralNotification;
extern NSString * const CMDidDisconnectPeripheralNotification;

@class KIBlueCentralManager;

typedef void(^CMDidStartScanBlock)              (KIBlueCentralManager *centralManager);
typedef void(^CMDidStopScanBlock)               (KIBlueCentralManager *centralManager);
typedef void(^CMDidUpdateStateBlock)            (KIBlueCentralManager *centralManager, CBCentralManagerState state);
typedef void(^CMDidDiscoverPeripheralBlock)     (KIBlueCentralManager *centralManager, KIPeripheral *peripheral);
typedef void(^CMDidConnectPeripheralBlock)      (KIBlueCentralManager *centralManager, KIPeripheral *peripheral, NSError *error);
typedef void(^CMDidConnectPeripheralsBlock)     (KIBlueCentralManager *centralManager, KIPeripheral *peripheral, NSError *error, BOOL finished);
typedef void(^CMDidDisconnectPeripheralBlock)   (KIBlueCentralManager *centralManager, KIPeripheral *peripheral, NSError *error);
typedef BOOL(^CMPeripheralFilterBlock)          (KIBlueCentralManager *centralManager, CBPeripheral *peripheral, NSDictionary *advertisementData);

@interface KIBlueCentralManager : NSObject <CBCentralManagerDelegate>

@property(readonly) CBCentralManagerState state;

+ (KIBlueCentralManager *)sharedInstance;

- (void)setup;

- (void)startScan:(CMDidStartScanBlock)block;

- (void)startScanAllowDuplicatesKey:(BOOL)allowDuplicatesKey block:(CMDidStartScanBlock)block;

- (void)startScanWithOptions:(NSDictionary *)options block:(CMDidStartScanBlock)block;

- (void)stopScan:(CMDidStopScanBlock)block;

- (NSArray *)peripherals;

/*
 设置外设的过滤器：
 当发现外设后，可以根据搜索到的外设的特征和广播数据判断是不是需要搜索的外设。返回YES或者NO
 */
- (void)setPeripheralFilterBlock:(CMPeripheralFilterBlock)block;

/*
 移除所有的Peripheral,包括已连接的
 移除之前，会调用disconnectAll，断开所有的连接
 */
- (void)removeAllPeripherals;

/*
 移除所有未连接的Peripheral
 */
- (void)removeAllDisconnectPeripherals;

//如果连接时的超时时间设置为0，在不需要的时候，如果连接仍然没有成功，一定要调用此方法
- (void)cancelConnect:(KIPeripheral *)peripheral;

- (void)connect:(KIPeripheral *)peripheral
        timeout:(NSInteger)timeout
       complete:(CMDidConnectPeripheralBlock)block;

- (void)connect:(KIPeripheral *)peripheral
        options:(NSDictionary *)options
        timeout:(NSInteger)timeout
       complete:(CMDidConnectPeripheralBlock)block;

- (void)connectWithPeripherls:(NSArray *)peripherals
                      timeout:(NSInteger)timeout
                     complete:(CMDidConnectPeripheralsBlock)block;

- (void)connectWithPeripherls:(NSArray *)peripherals
                      options:(NSDictionary *)options
                      timeout:(NSInteger)timeout
                     complete:(CMDidConnectPeripheralsBlock)block;

- (void)disconnect:(KIPeripheral *)peripheral;

- (void)disconnectAll;

- (void)setDidUpdateStateBlock:(CMDidUpdateStateBlock)block;

- (void)setDidDiscoverPeripheralBlock:(CMDidDiscoverPeripheralBlock)block;

- (void)setDidDisconnectPeripheralBlock:(CMDidDisconnectPeripheralBlock)block;

@end
