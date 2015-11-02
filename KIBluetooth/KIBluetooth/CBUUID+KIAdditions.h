//
//  CBUUID+KIAdditions.h
//  Kitalker
//
//  Created by Kitalker on 14-1-14.
//  Copyright (c) 2014年 杨 烽. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>

@interface CBUUID (KIAdditions)

- (NSString *)UUIDString;

@end


@interface CBService (UUIDString)

- (NSString *)UUIDString;

@end


@interface CBCharacteristic (UUIDString)

- (NSString *)UUIDString;

@end


@interface CBCentral (UUIDString)

- (NSString *)UUIDString;

@end