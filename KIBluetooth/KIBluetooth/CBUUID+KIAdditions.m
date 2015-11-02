//
//  CBUUID+KIAdditions.m
//  Kitalker
//
//  Created by Kitalker on 14-1-14.
//  Copyright (c) 2014年 杨 烽. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CBUUID+KIAdditions.h"

@implementation CBUUID (KIAdditions)

- (NSString *)UUIDString {
    NSData *data = self.data;
    NSUInteger bytesToConvert = [data length];
    const unsigned char *uuidBytes = [data bytes];
    NSMutableString *outputString = [NSMutableString stringWithCapacity:16];
    
    for (NSUInteger currentByteIndex = 0; currentByteIndex < bytesToConvert; currentByteIndex++) {
        switch (currentByteIndex) {
            case 3:
            case 5:
            case 7:
            case 9: [outputString appendFormat:@"%02x-", uuidBytes[currentByteIndex]]; break;
            default: [outputString appendFormat:@"%02x", uuidBytes[currentByteIndex]];
        }
    }
    
    NSString *result = [outputString uppercaseString];
    
    return result;
}

@end


@implementation CBService (UUIDString)

- (NSString *)UUIDString {
    return self.UUID.UUIDString;
}

@end


@implementation CBCharacteristic (UUIDString)

- (NSString *)UUIDString {
    return self.UUID.UUIDString;
}

@end


@implementation CBCentral (UUIDString)

- (NSString *)UUIDString {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        return self.identifier.UUIDString;
    }
    if ([self respondsToSelector:@selector(UUID)]) {
        CFUUIDRef uuid = (__bridge CFUUIDRef)([self performSelector:@selector(UUID)]);
        CBUUID *tempUUID = [CBUUID UUIDWithCFUUID:uuid];
        return tempUUID.UUIDString;
    }
    return nil;
}

@end
