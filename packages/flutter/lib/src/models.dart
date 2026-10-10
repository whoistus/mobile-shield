enum ThreatCategory {
  root('ROOT'),
  emulator('EMULATOR'),
  debugger('DEBUGGER'),
  hooking('HOOKING'),
  tampering('TAMPERING'),
  installer('INSTALLER'),
  screenCapture('SCREEN_CAPTURE'),
  devOptionsAdb('DEV_OPTIONS_ADB'),
  noDeviceLock('NO_DEVICE_LOCK'),
  vpnProxy('VPN_PROXY');

  const ThreatCategory(this.value);

  final String value;

  static ThreatCategory fromValue(Object? value) => values.firstWhere(
        (e) => e.value == value,
        orElse: () => throw FormatException('Unknown ThreatCategory', value),
      );
}

enum ThreatAction {
  report('REPORT'),
  warn('WARN'),
  block('BLOCK'),
  kill('KILL');

  const ThreatAction(this.value);

  final String value;

  static ThreatAction fromValue(Object? value) => values.firstWhere(
        (e) => e.value == value,
        orElse: () => throw FormatException('Unknown ThreatAction', value),
      );
}

enum Severity {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH'),
  critical('CRITICAL');

  const Severity(this.value);

  final String value;

  static Severity fromValue(Object? value) => values.firstWhere(
        (e) => e.value == value,
        orElse: () => throw FormatException('Unknown Severity', value),
      );
}

class ThreatEvent {
  const ThreatEvent({
    required this.category,
    required this.severity,
    required this.confidence,
    required this.detectorId,
    required this.action,
    required this.timestamp,
    required this.platform,
    this.details = const {},
  });

  factory ThreatEvent.fromJson(Map<String, Object?> json) => ThreatEvent(
        category: ThreatCategory.fromValue(json['category']),
        severity: Severity.fromValue(json['severity']),
        confidence: (json['confidence'] as num).toDouble(),
        detectorId: json['detectorId'] as String,
        action: ThreatAction.fromValue(json['action']),
        timestamp: (json['timestamp'] as num).toInt(),
        platform: json['platform'] as String,
        details: _stringMap(json['details']),
      );

  final ThreatCategory category;
  final Severity severity;
  final double confidence;
  final String detectorId;

  /// What native applied. Dart never derives enforcement from this.
  final ThreatAction action;

  /// Epoch milliseconds.
  final int timestamp;
  final String platform;
  final Map<String, String> details;

  bool get isBlocking => action == ThreatAction.block || action == ThreatAction.kill;

  @override
  String toString() => 'ThreatEvent($detectorId ${category.value} ${action.value} $confidence)';
}

class EnvironmentInfo {
  const EnvironmentInfo({
    required this.sdkVersion,
    required this.platform,
    required this.osVersion,
    required this.abi,
    required this.isDebuggable,
    required this.gmsAvailable,
    required this.hmsAvailable,
    required this.installer,
    required this.attestationKinds,
  });

  factory EnvironmentInfo.fromJson(Map<String, Object?> json) => EnvironmentInfo(
        sdkVersion: json['sdkVersion'] as String,
        platform: json['platform'] as String,
        osVersion: json['osVersion'] as String,
        abi: json['abi'] as String,
        isDebuggable: json['isDebuggable'] as bool,
        gmsAvailable: json['gmsAvailable'] as bool,
        hmsAvailable: json['hmsAvailable'] as bool,
        installer: json['installer'] as String?,
        attestationKinds: _stringList(json['attestationKinds']),
      );

  final String sdkVersion;
  final String platform;
  final String osVersion;
  final String abi;
  final bool isDebuggable;
  final bool gmsAvailable;
  final bool hmsAvailable;
  final String? installer;
  final List<String> attestationKinds;
}

/// Effective config after bootstrap, channel defaults, host config and the native floor.
class AppliedConfig {
  const AppliedConfig({
    required this.channel,
    required this.policies,
    required this.disabled,
    required this.unsupportedDetectors,
    required this.blockThreshold,
    required this.monitoringIntervalMs,
    required this.killDelayMsRange,
    required this.installerAllowlist,
    required this.seq,
    required this.clamped,
  });

  factory AppliedConfig.fromJson(Map<String, Object?> json) {
    final policies = <ThreatCategory, ThreatAction>{};
    final raw = json['policies'];
    if (raw is Map) {
      raw.forEach((k, v) => policies[ThreatCategory.fromValue(k)] = ThreatAction.fromValue(v));
    }
    final range = (json['killDelayMsRange'] as List?)?.map((e) => (e as num).toInt()).toList();
    return AppliedConfig(
      channel: json['channel'] as String,
      policies: policies,
      disabled: _stringList(json['disabled']),
      unsupportedDetectors: _stringList(json['unsupportedDetectors']),
      blockThreshold: (json['blockThreshold'] as num).toDouble(),
      monitoringIntervalMs: (json['monitoringIntervalMs'] as num).toInt(),
      killDelayMsRange: range == null || range.length != 2 ? const [0, 0] : range,
      installerAllowlist: _stringList(json['installerAllowlist']),
      seq: (json['seq'] as num).toInt(),
      clamped: _stringList(json['clamped']),
    );
  }

  final String channel;
  final Map<ThreatCategory, ThreatAction> policies;

  /// Detector ids switched off by the host config.
  final List<String> disabled;

  /// iOS only: detector ids the device cannot run; they emit no events.
  final List<String> unsupportedDetectors;
  final double blockThreshold;
  final int monitoringIntervalMs;
  final List<int> killDelayMsRange;
  final List<String> installerAllowlist;
  final int seq;

  /// Values the native floor overrode; empty when nothing was clamped.
  final List<String> clamped;

  bool isEnabled(String detectorId) => !disabled.contains(detectorId);
}

/// Attestation is reserved: `status` is always `unsupported` in this version.
class AttestationResult {
  const AttestationResult({required this.status, required this.kind});

  factory AttestationResult.fromJson(Map<String, Object?> json) => AttestationResult(
        status: json['status'] as String,
        kind: json['kind'] as String?,
      );

  final String status;
  final String? kind;

  bool get isUnsupported => status == 'unsupported';
}

Map<String, String> _stringMap(Object? value) => value is Map
    ? value.map((k, v) => MapEntry(k as String, '$v'))
    : const {};

List<String> _stringList(Object? value) =>
    value is List ? value.map((e) => e as String).toList(growable: false) : const [];
