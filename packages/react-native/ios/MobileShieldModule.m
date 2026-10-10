#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <MobileShieldCore/MobileShield.h>

static NSString *const kThreatEvent = @"MobileShield.onThreat";

/// Thin bridge: forwards to the native facade and never decides enforcement.
/// Config crosses as a JSON string so numeric types survive for signature canonicalisation.
@interface MobileShieldModule : RCTEventEmitter <RCTBridgeModule>
@property(nonatomic, strong) id listenerToken;
@property(nonatomic, strong) dispatch_queue_t queue;
@end

@implementation MobileShieldModule

RCT_EXPORT_MODULE(MobileShield)

+ (BOOL)requiresMainQueueSetup { return NO; }

- (dispatch_queue_t)methodQueue {
  if (!_queue) _queue = dispatch_queue_create("io.mobileshield.rn", DISPATCH_QUEUE_SERIAL);
  return _queue;
}

- (NSArray<NSString *> *)supportedEvents { return @[kThreatEvent]; }

- (void)startObserving {
  if (self.listenerToken) return;
  __weak typeof(self) weakSelf = self;
  self.listenerToken = [MobileShield addListener:^(NSDictionary *event) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (strongSelf) [strongSelf sendEventWithName:kThreatEvent body:[strongSelf encode:event]];
  }];
}

- (void)stopObserving {
  if (self.listenerToken) [MobileShield removeListener:self.listenerToken];
  self.listenerToken = nil;
}

- (void)invalidate {
  [self stopObserving];
  [super invalidate];
}

- (NSString *)encode:(id)value {
  if (![NSJSONSerialization isValidJSONObject:value]) return @"{}";
  NSData *data = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}

/// Returns nil with *failed = YES when the string is not a JSON object.
- (NSDictionary *)parse:(NSString *)json failed:(BOOL *)failed {
  *failed = NO;
  if (!json) return nil;
  NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
  id value = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
  if (![value isKindOfClass:[NSDictionary class]]) *failed = YES;
  return *failed ? nil : value;
}

// Same shape as Android: code = typed error name, userInfo.reason = ConfigRejected sub-reason.
- (void)reject:(RCTPromiseRejectBlock)reject error:(NSError *)error {
  NSString *code = @"NativeUnavailable";
  NSString *sub = nil;
  if ([error.domain isEqualToString:MSErrorDomain]) {
    switch ((MSErrorCode)error.code) {
      case MSErrorNativeUnavailable: code = @"NativeUnavailable"; break;
      case MSErrorNotInitialized: code = @"NotInitialized"; break;
      case MSErrorBootstrapMissing: code = @"BootstrapMissing"; break;
      case MSErrorConfigRejected: code = @"ConfigRejected"; sub = error.userInfo[@"configReason"]; break;
      case MSErrorDetectorUnsupported: code = @"DetectorUnsupported"; break;
      case MSErrorAttestationUnsupported: code = @"AttestationUnsupported"; break;
    }
  }
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  if (sub) info[@"reason"] = sub;
  NSError *mapped = [NSError errorWithDomain:MSErrorDomain code:error.code userInfo:info];
  reject(code, error.localizedDescription, mapped);
}

- (void)rejectBadConfig:(RCTPromiseRejectBlock)reject {
  NSError *error = [NSError errorWithDomain:MSErrorDomain code:MSErrorConfigRejected userInfo:@{
    NSLocalizedDescriptionKey: @"runtime config is not valid JSON",
    @"configReason": @"schema"}];
  [self reject:reject error:error];
}

RCT_REMAP_METHOD(getSdkVersion, versionResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  resolve([MobileShield sdkVersion]);
}

RCT_REMAP_METHOD(init, initWithConfig:(NSString *)configJson resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  BOOL failed; NSDictionary *config = [self parse:configJson failed:&failed];
  if (failed) { [self rejectBadConfig:reject]; return; }
  NSError *error = nil; NSDictionary *value = [MobileShield initWithConfig:config error:&error];
  if (error) [self reject:reject error:error]; else resolve([self encode:value]);
}

RCT_REMAP_METHOD(updateConfig, updateWithConfig:(NSString *)configJson resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  BOOL failed; NSDictionary *config = [self parse:configJson failed:&failed];
  if (failed || !config) { [self rejectBadConfig:reject]; return; }
  NSError *error = nil; NSDictionary *value = [MobileShield updateConfig:config error:&error];
  if (error) [self reject:reject error:error]; else resolve([self encode:value]);
}

// The native facade returns an empty config before init; surface that as NotInitialized like Android.
- (BOOL)rejectIfNotInitialized:(RCTPromiseRejectBlock)reject {
  if ([MobileShield getConfig].count > 0) return NO;
  reject(@"NotInitialized", @"MobileShield.init has not been called", nil);
  return YES;
}

RCT_REMAP_METHOD(getConfig, configResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  if ([self rejectIfNotInitialized:reject]) return;
  resolve([self encode:[MobileShield getConfig]]);
}

RCT_REMAP_METHOD(runChecks, checksResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  resolve([self encode:[MobileShield runChecks]]);
}

RCT_REMAP_METHOD(startMonitoring, startResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  if ([self rejectIfNotInitialized:reject]) return;
  [MobileShield startMonitoring]; resolve(nil);
}

RCT_REMAP_METHOD(stopMonitoring, stopResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  [MobileShield stopMonitoring]; resolve(nil);
}

RCT_REMAP_METHOD(isBlocked, blockedResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  resolve(@([MobileShield isBlocked]));
}

RCT_REMAP_METHOD(attestEnrol, enrol:(NSString *)kind nonce:(NSString *)nonce resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  resolve([self encode:[MobileShield attestEnrol:kind nonce:nonce]]);
}

RCT_REMAP_METHOD(attestAssert, assertion:(NSString *)kind nonce:(NSString *)nonce requestHash:(NSString *)hash resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
  resolve([self encode:[MobileShield attestAssert:kind nonce:nonce requestHash:hash]]);
}

@end
