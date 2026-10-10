#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MSThreatListener)(NSDictionary<NSString *, id> *event);

/// NSError domain for every typed SDK error. `userInfo[@"reason"]` is the stable wrapper code
/// (for example "NotInitialized" or "ConfigRejected.floor"); ConfigRejected also sets
/// `userInfo[@"configReason"]` to signature | floor | schema | expired.
FOUNDATION_EXPORT NSErrorDomain const MSErrorDomain;

typedef NS_ERROR_ENUM(MSErrorDomain, MSErrorCode) {
    MSErrorNativeUnavailable = 1,
    MSErrorNotInitialized = 2,
    MSErrorBootstrapMissing = 3,
    MSErrorConfigRejected = 4,
    MSErrorDetectorUnsupported = 5,
    MSErrorAttestationUnsupported = 6,
};

@interface MobileShield : NSObject
+ (NSString *)sdkVersion;
+ (NSDictionary<NSString *, id> *)initWithConfig:(nullable NSDictionary<NSString *, id> *)config error:(NSError **)error;
+ (NSDictionary<NSString *, id> *)updateConfig:(NSDictionary<NSString *, id> *)config error:(NSError **)error;
+ (NSDictionary<NSString *, id> *)getConfig;
+ (NSArray<NSDictionary<NSString *, id> *> *)runChecks;
+ (void)startMonitoring;
+ (void)stopMonitoring;
+ (BOOL)isBlocked;
+ (NSDictionary<NSString *, id> *)attestEnrol:(NSString *)kind nonce:(NSString *)nonce;
+ (NSDictionary<NSString *, id> *)attestAssert:(NSString *)kind nonce:(NSString *)nonce requestHash:(NSString *)requestHash;
+ (id)addListener:(MSThreatListener)listener;
+ (void)removeListener:(id)token;
@end

NS_ASSUME_NONNULL_END
