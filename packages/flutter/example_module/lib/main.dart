import 'package:flutter/material.dart';
import 'package:mobile_shield/mobile_shield.dart';

/// Must equal the host app's applicationId (see example_host/app/build.gradle).
const hostAppId = 'io.mobileshield.example.host';

void main() => runApp(const ModuleApp());

class ModuleApp extends StatelessWidget {
  const ModuleApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: Scaffold(body: Center(child: Status())));
}

class Status extends StatefulWidget {
  const Status({super.key});

  @override
  State<Status> createState() => _StatusState();
}

class _StatusState extends State<Status> {
  String text = 'starting';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final info = await MobileShield.init({'version': 1, 'appId': hostAppId, 'seq': 1});
      final blocked = await MobileShield.isBlocked();
      text = 'sdkVersion=${info.sdkVersion} blocked=$blocked';
    } on MobileShieldException catch (e) {
      text = '$e';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Text(text);
}
