#import "MobileShield.h"

#ifndef MS_VERSION
#define MS_VERSION "0.0.0"
#endif

// Implemented in Internal.swift (internal, not part of the public header).
@interface MSInternal : NSObject
+ (NSString *)normalizedVersion:(NSString *)raw;
@end

@implementation MobileShield

+ (NSString *)sdkVersion {
    return [MSInternal normalizedVersion:@MS_VERSION];
}

@end
