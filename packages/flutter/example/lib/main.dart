import 'package:flutter/material.dart';
import 'package:mobile_shield/mobile_shield.dart';

import 'remote_config_screen.dart';
import 'shield_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final controller = ShieldController();

  @override
  void initState() {
    super.initState();
    controller.start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mobile Shield',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (!controller.ready) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (controller.blocked) return BlockedScreen(controller: controller);
            return HomeScreen(controller: controller);
          },
        ),
      );
}

/// Root-level gate: the decision comes from native isBlocked(), never from Dart.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key, required this.controller});

  final ShieldController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad, size: 64),
                const SizedBox(height: 16),
                const Text('Protected operations are blocked on this device.'),
                if (controller.error != null) Text(controller.error!),
                for (final e in controller.events.where((e) => e.isBlocking))
                  Text('${e.detectorId} (${e.category.value})'),
              ],
            ),
          ),
        ),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final ShieldController controller;

  @override
  Widget build(BuildContext context) {
    final info = controller.info;
    return Scaffold(
      appBar: AppBar(title: const Text('Mobile Shield')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (info != null) ...[
            Text('sdkVersion: ${controller.sdkVersion}'),
            Text('platform: ${info.platform}  os: ${info.osVersion}  abi: ${info.abi}'),
            Text('debuggable: ${info.isDebuggable}  gms: ${info.gmsAvailable}  hms: ${info.hmsAvailable}'),
            Text('installer: ${info.installer ?? 'none'}'),
            Text('channel: ${controller.config?.channel ?? '?'}  attestation: ${info.attestationKinds}'),
          ],
          if (controller.error != null) Text(controller.error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(onPressed: controller.runChecks, child: const Text('Run checks')),
              FilledButton(
                onPressed: controller.toggleMonitoring,
                child: Text(controller.monitoring ? 'Stop monitoring' : 'Start monitoring'),
              ),
              FilledButton(
                onPressed: () async {
                  final message = await controller.pushConfig({'monitoringIntervalMs': 2000});
                  if (message != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                  }
                },
                child: const Text('Update config (2s interval)'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => RemoteConfigScreen(controller: controller),
                )),
                child: const Text('Remote config'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Events (${controller.events.length})', style: Theme.of(context).textTheme.titleMedium),
          for (final ThreatEvent e in controller.events)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${e.detectorId}  ${e.action.value}'),
              subtitle: Text('${e.category.value} ${e.severity.value} conf ${e.confidence.toStringAsFixed(2)}'),
            ),
        ],
      ),
    );
  }
}
