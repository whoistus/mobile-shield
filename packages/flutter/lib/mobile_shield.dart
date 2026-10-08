import 'package:flutter/services.dart';

class MobileShield {
  static const MethodChannel _channel = MethodChannel('mobile_shield');

  static Future<String> getSdkVersion() async {
    final v = await _channel.invokeMethod<String>('getSdkVersion');
    return v ?? '';
  }
}
