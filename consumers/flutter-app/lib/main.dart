import 'package:flutter/material.dart';
import 'package:mobile_shield/mobile_shield.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final v = await MobileShield.getSdkVersion();
  debugPrint('sdkVersion=$v');
  runApp(MaterialApp(home: Scaffold(body: Center(child: Text('sdkVersion=$v')))));
}
