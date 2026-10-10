/// Flutter bridge to the native mobile-shield core. Native decides and enforces;
/// this library only forwards config and reports what native did.
library;

import 'src/channel.dart';
import 'src/models.dart';

export 'src/errors.dart';
export 'src/models.dart';

class MobileShield {
  const MobileShield._();

  /// Reads bootstrap from the host bundle natively; idempotent. Throws
  /// [ConfigRejectedException] for a rejected [config] while the SDK stays initialised.
  static Future<EnvironmentInfo> init(Map<String, Object?> config) async =>
      EnvironmentInfo.fromJson(await MobileShieldChannel.invokeObject('init', config));

  /// Floor violations throw [ConfigRejectedException] (`floor`) with the clamped config active.
  static Future<AppliedConfig> updateConfig(Map<String, Object?> config) async =>
      AppliedConfig.fromJson(await MobileShieldChannel.invokeObject('updateConfig', config));

  static Future<AppliedConfig> getConfig() async =>
      AppliedConfig.fromJson(await MobileShieldChannel.invokeObject('getConfig'));

  static Future<List<ThreatEvent>> runChecks() => MobileShieldChannel.invokeEvents('runChecks');

  static Future<void> startMonitoring() => MobileShieldChannel.invoke<void>('startMonitoring');

  static Future<void> stopMonitoring() => MobileShieldChannel.invoke<void>('stopMonitoring');

  /// Native-held, sticky for the process lifetime. Check before every protected operation.
  static Future<bool> isBlocked() async =>
      // Fail closed: a missing answer is treated as blocked.
      await MobileShieldChannel.invoke<bool>('isBlocked') ?? true;

  static Future<AttestationResult> attestEnrol(String kind, String nonce) async =>
      AttestationResult.fromJson(await MobileShieldChannel.invokeObject(
          'attestEnrol', {'kind': kind, 'nonce': nonce}));

  static Future<AttestationResult> attestAssert(
          String kind, String nonce, String requestHash) async =>
      AttestationResult.fromJson(await MobileShieldChannel.invokeObject(
          'attestAssert', {'kind': kind, 'nonce': nonce, 'requestHash': requestHash}));

  static Future<String> sdkVersion() async =>
      await MobileShieldChannel.invoke<String>('getSdkVersion') ?? '';

  static Stream<ThreatEvent> get threats => MobileShieldChannel.threats;
}
