import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile_shield/mobile_shield.dart';

/// Must equal the Android applicationId and the iOS bundle id (checked natively).
const exampleAppId = 'io.mobileshield.example.mobileShieldExample';

class ShieldController extends ChangeNotifier {
  EnvironmentInfo? info;
  String sdkVersion = '';
  AppliedConfig? config;
  String? error;
  bool ready = false;
  bool blocked = false;
  bool monitoring = false;
  final List<ThreatEvent> events = [];

  StreamSubscription<ThreatEvent>? _subscription;
  int _seq = 0;

  Future<void> start() async {
    // Listen before init so nothing the first pass raises is missed.
    _subscription = MobileShield.threats.listen(
      (event) {
        events.insert(0, event);
        if (events.length > 50) events.removeLast();
        notifyListeners();
        // Native owns enforcement; ask it instead of reading event.action.
        unawaited(refreshBlocked());
      },
      onError: (Object e) {
        error = '$e';
        notifyListeners();
      },
    );
    try {
      info = await MobileShield.init({'version': 1, 'appId': exampleAppId, 'seq': _nextSeq()});
    } on ConfigRejectedException catch (e) {
      error = 'init: $e (${e.reason?.name})';
    } on MobileShieldException catch (e) {
      error = 'init: $e';
    }
    sdkVersion = await _guard(MobileShield.sdkVersion) ?? '';
    config = await _guard(MobileShield.getConfig);
    // Fail closed: if init failed natively we do not render the protected app.
    blocked = info == null ? true : await MobileShield.isBlocked();
    ready = true;
    notifyListeners();
  }

  Future<void> refreshBlocked() async {
    final value = await _guard(MobileShield.isBlocked) ?? true;
    if (value != blocked) {
      blocked = value;
      notifyListeners();
    }
  }

  Future<void> runChecks() async {
    final result = await _guard(MobileShield.runChecks);
    if (result != null) {
      events
        ..clear()
        ..addAll(result.reversed);
      notifyListeners();
    }
    await refreshBlocked();
  }

  Future<void> toggleMonitoring() async {
    await _guard(monitoring ? MobileShield.stopMonitoring : MobileShield.startMonitoring);
    monitoring = !monitoring;
    notifyListeners();
  }

  /// Returns null on success, or a message describing the rejection.
  Future<String?> pushConfig(Map<String, Object?> partial) async {
    String? message;
    try {
      config = await MobileShield.updateConfig({
        'version': 1,
        'appId': exampleAppId,
        'seq': _nextSeq(),
        ...partial,
      });
    } on ConfigRejectedException catch (e) {
      message = 'ConfigRejected(${e.reason?.name}): ${e.message ?? ''}';
    } on MobileShieldException catch (e) {
      message = '$e';
    }
    // After a floor clamp the clamped config is active; read back what native kept.
    config = await _guard(MobileShield.getConfig) ?? config;
    notifyListeners();
    return message;
  }

  Future<T?> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on MobileShieldException catch (e) {
      error = '$e';
      notifyListeners();
      return null;
    }
  }

  // Seconds-based so it stays above the seq native persisted on a previous launch.
  int _nextSeq() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _seq = now > _seq ? now : _seq + 1;
    return _seq;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
