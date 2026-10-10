#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Extension point for future attestation add-ons (App Attest, HMS). No implementation ships in
/// this version: no backend verifier exists, so MobileShield.attest* always report "unsupported".
@protocol MSAttestationProvider <NSObject>
- (NSString *)kind;
- (BOOL)isAvailable;
- (NSDictionary<NSString *, id> *)enrolWithNonce:(NSString *)nonce;
- (NSDictionary<NSString *, id> *)assertWithNonce:(NSString *)nonce requestHash:(NSString *)requestHash;
@end

NS_ASSUME_NONNULL_END
