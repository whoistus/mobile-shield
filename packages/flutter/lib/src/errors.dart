import 'package:flutter/services.dart';

/// Base of every typed SDK error. Unknown native codes surface as this class.
class MobileShieldException implements Exception {
  const MobileShieldException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => message == null ? code : '$code: $message';
}

class NativeUnavailableException extends MobileShieldException {
  const NativeUnavailableException([String? message])
      : super('NativeUnavailable', message);
}

class NotInitializedException extends MobileShieldException {
  const NotInitializedException([String? message])
      : super('NotInitialized', message);
}

class BootstrapMissingException extends MobileShieldException {
  const BootstrapMissingException([String? message])
      : super('BootstrapMissing', message);
}

enum ConfigRejectedReason {
  signature,
  floor,
  schema,
  expired;

  static ConfigRejectedReason? tryParse(Object? value) {
    for (final reason in values) {
      if (reason.name == value) return reason;
    }
    return null;
  }
}

/// The SDK stays initialised on rejection; for [ConfigRejectedReason.floor] the
/// clamped config is active, so call `getConfig()` to see what was changed.
class ConfigRejectedException extends MobileShieldException {
  const ConfigRejectedException(this.reason, [String? message])
      : super('ConfigRejected', message);

  final ConfigRejectedReason? reason;
}

class DetectorUnsupportedException extends MobileShieldException {
  const DetectorUnsupportedException(this.id, [String? message])
      : super('DetectorUnsupported', message);

  final String? id;
}

class AttestationUnsupportedException extends MobileShieldException {
  const AttestationUnsupportedException(this.kind, [String? message])
      : super('AttestationUnsupported', message);

  final String? kind;
}

/// Maps whatever the channel layer threw to a typed exception; non-SDK errors pass through.
Object mapError(Object error) {
  if (error is MobileShieldException) return error;
  if (error is MissingPluginException) {
    return NativeUnavailableException(error.message);
  }
  if (error is! PlatformException) return error;

  final details = error.details;
  final map = details is Map ? details : const <Object?, Object?>{};
  final message = error.message;
  // iOS reports "ConfigRejected.<why>" in the code if a bridge forwards it unsplit.
  final dot = error.code.indexOf('.');
  final code = dot < 0 ? error.code : error.code.substring(0, dot);
  switch (code) {
    case 'NativeUnavailable':
      return NativeUnavailableException(message);
    case 'NotInitialized':
      return NotInitializedException(message);
    case 'BootstrapMissing':
      return BootstrapMissingException(message);
    case 'ConfigRejected':
      final reason = ConfigRejectedReason.tryParse(map['reason']) ??
          (dot < 0 ? null : ConfigRejectedReason.tryParse(error.code.substring(dot + 1)));
      return ConfigRejectedException(reason, message);
    case 'DetectorUnsupported':
      return DetectorUnsupportedException(map['id'] as String?, message);
    case 'AttestationUnsupported':
      return AttestationUnsupportedException(map['kind'] as String?, message);
    default:
      return MobileShieldException(error.code, message);
  }
}
