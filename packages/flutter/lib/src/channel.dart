import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'errors.dart';
import 'models.dart';

/// Thin transport over the platform channels. Native returns JSON strings so both
/// platforms share one wire shape; every failure is mapped to a typed exception.
class MobileShieldChannel {
  const MobileShieldChannel._();

  static const MethodChannel method = MethodChannel('mobile_shield');
  static const EventChannel events = EventChannel('mobile_shield/threats');

  static Stream<ThreatEvent>? _threats;

  static Future<T?> invoke<T>(String name, [Object? arguments]) async {
    try {
      return await method.invokeMethod<T>(name, arguments);
    } catch (error, stack) {
      Error.throwWithStackTrace(mapError(error), stack);
    }
  }

  static Future<Map<String, Object?>> invokeObject(String name, [Object? arguments]) async {
    final raw = await invoke<String>(name, arguments);
    return _decodeObject(raw);
  }

  static Future<List<ThreatEvent>> invokeEvents(String name) async {
    final raw = await invoke<String>(name) ?? '[]';
    return (jsonDecode(raw) as List)
        .map((e) => ThreatEvent.fromJson((e as Map).cast<String, Object?>()))
        .toList(growable: false);
  }

  /// Broadcast: native delivery starts with the first listener and stops after the last cancels.
  static Stream<ThreatEvent> get threats => _threats ??= events
      .receiveBroadcastStream()
      .transform(StreamTransformer<dynamic, ThreatEvent>.fromHandlers(
        handleData: (data, sink) {
          try {
            sink.add(ThreatEvent.fromJson(_decodeObject(data as String?)));
          } catch (error, stack) {
            sink.addError(error, stack);
          }
        },
        handleError: (error, stack, sink) => sink.addError(mapError(error), stack),
      ));

  static Map<String, Object?> _decodeObject(String? raw) =>
      (jsonDecode(raw ?? '{}') as Map).cast<String, Object?>();
}
