#import <Foundation/Foundation.h>

#import <MobileShieldCore/MobileShield.h>
#import "MobileShield.h"
#import "Attest/AttestationProvider.h"

#ifndef MS_VERSION
#define MS_VERSION "0.0.0"
#endif

NSErrorDomain const MSErrorDomain = @"io.mobileshield";

@interface MSInternal : NSObject
+ (NSDictionary *)setupWithConfig:(NSDictionary * _Nullable)config sdkVersion:(NSString *)sdkVersion error:(NSError **)error;
+ (NSDictionary *)updateWithConfig:(NSDictionary *)config error:(NSError **)error;
+ (NSDictionary *)config;
+ (NSArray<NSDictionary *> *)checks;
+ (void)start;
+ (void)stop;
+ (BOOL)blocked;
+ (id)listen:(MSThreatListener)listener;
+ (void)unlisten:(id)token;
@end

/// No provider ships in this version; add-ons register here without an API change.
static NSArray<id<MSAttestationProvider>> *MSAttestationProviders(void) { return @[]; }

static NSDictionary *MSAttestationResult(NSString *kind, NSString *nonce, NSString * _Nullable requestHash) {
    for (id<MSAttestationProvider> provider in MSAttestationProviders()) {
        if (![[provider kind] isEqualToString:kind] || ![provider isAvailable]) continue;
        return requestHash ? [provider assertWithNonce:nonce requestHash:requestHash] : [provider enrolWithNonce:nonce];
    }
    return @{ @"status": @"unsupported", @"kind": kind };
}

@implementation MobileShield
+ (NSString *)sdkVersion { return [@MS_VERSION stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; }
+ (NSDictionary *)initWithConfig:(NSDictionary *)config error:(NSError **)error { return [MSInternal setupWithConfig:config sdkVersion:[self sdkVersion] error:error]; }
+ (NSDictionary *)updateConfig:(NSDictionary *)config error:(NSError **)error { return [MSInternal updateWithConfig:config error:error]; }
+ (NSDictionary *)getConfig { return [MSInternal config]; }
+ (NSArray<NSDictionary *> *)runChecks { return [MSInternal checks]; }
+ (void)startMonitoring { [MSInternal start]; }
+ (void)stopMonitoring { [MSInternal stop]; }
+ (BOOL)isBlocked { return [MSInternal blocked]; }
+ (NSDictionary *)attestEnrol:(NSString *)kind nonce:(NSString *)nonce { return MSAttestationResult(kind, nonce, nil); }
+ (NSDictionary *)attestAssert:(NSString *)kind nonce:(NSString *)nonce requestHash:(NSString *)requestHash { return MSAttestationResult(kind, nonce, requestHash); }
+ (id)addListener:(MSThreatListener)listener { return [MSInternal listen:listener]; }
+ (void)removeListener:(id)token { [MSInternal unlisten:token]; }
@end
