import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:mobile_shield/mobile_shield.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // build.sh greps the device log for this line to prove the native core linked.
  debugPrint('sdkVersion=${await MobileShield.sdkVersion()}');
  runApp(const ShieldExample());
}

class ShieldExample extends StatefulWidget {
  const ShieldExample({super.key});
  @override
  State<ShieldExample> createState() => _ShieldExampleState();
}

class _ShieldExampleState extends State<ShieldExample> {
  String status = 'Starting security checks';
  bool blocked = true;
  List<ThreatEvent> events = [];
  @override
  void initState() {
    super.initState();
    MobileShield.threats.listen((event) {
      if (!mounted) return;
      setState(() {
        events = [event, ...events].take(25).toList();
        if (event.isBlocking) blocked = true;
      });
    });
    _initialize();
  }
  Future<void> _initialize() async {
    try {
      final info = await MobileShield.init({
        'version': 1,
        // Must equal the Android applicationId / iOS bundle id, which differ for this app.
        'appId': Platform.isIOS ? 'io.mobileshield.consumer.flutterApp' : 'io.mobileshield.consumer.flutter_app',
        'seq': 1,
      });
      final value = await MobileShield.isBlocked();
      await MobileShield.startMonitoring();
      if (!mounted) return;
      setState(() {
        status = '${info.sdkVersion} · ${info.platform}';
        blocked = value;
      });
    } catch (error) {
      if (mounted) setState(() { status = '$error'; blocked = true; });
    }
  }
  @override
  Widget build(BuildContext context) => MaterialApp(home: Scaffold(
    appBar: AppBar(title: const Text('Mobile Shield')),
    body: ListView(children: [
      Text(status),
      Text(blocked ? 'Protected operations blocked' : 'Ready'),
      ElevatedButton(onPressed: () async {
        final next = await MobileShield.runChecks();
        if (mounted) setState(() => events = next);
      }, child: const Text('Run checks')),
      ...events.map((e) => ListTile(title: Text('${e.detectorId}: ${e.action.value}'))),
    ]),
  ));
}
