import 'package:flutter/material.dart';
import 'package:mobile_shield/mobile_shield.dart';

import 'detector_ids.dart';
import 'shield_controller.dart';

/// Stands in for a config fetched from your server: edit, push through updateConfig,
/// then compare what you asked for with what native kept (getConfig).
class RemoteConfigScreen extends StatefulWidget {
  const RemoteConfigScreen({super.key, required this.controller});

  final ShieldController controller;

  @override
  State<RemoteConfigScreen> createState() => _RemoteConfigScreenState();
}

class _RemoteConfigScreenState extends State<RemoteConfigScreen> {
  final Map<ThreatCategory, ThreatAction> _requested = {};
  final Map<String, bool> _detectors = {};
  String? _result;

  @override
  void initState() {
    super.initState();
    final applied = widget.controller.config;
    for (final category in ThreatCategory.values) {
      _requested[category] = applied?.policies[category] ?? ThreatAction.report;
    }
    for (final entry in [...androidDetectors, ...iosDetectors]) {
      _detectors[entry.id] = applied?.isEnabled(entry.id) ?? true;
    }
  }

  Future<void> _apply() async {
    final message = await widget.controller.pushConfig({
      'policies': {for (final e in _requested.entries) e.key.value: e.value.value},
      'detectors': _detectors,
    });
    if (mounted) setState(() => _result = message ?? 'Applied');
  }

  @override
  Widget build(BuildContext context) {
    final applied = widget.controller.config;
    return Scaffold(
      appBar: AppBar(title: const Text('Remote config')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Actions', style: Theme.of(context).textTheme.titleMedium),
          for (final category in ThreatCategory.values) _actionRow(category, applied),
          const SizedBox(height: 16),
          Text('Native result', style: Theme.of(context).textTheme.titleMedium),
          Text(_result ?? 'Not pushed yet'),
          if (applied != null) ...[
            Text('clamped by floor: ${applied.clamped.isEmpty ? 'none' : applied.clamped.join(', ')}'),
            Text('disabled: ${applied.disabled.isEmpty ? 'none' : applied.disabled.join(', ')}'),
            if (applied.unsupportedDetectors.isNotEmpty)
              Text('unsupported on this device: ${applied.unsupportedDetectors.join(', ')}'),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _apply, child: const Text('Push via updateConfig')),
          const SizedBox(height: 16),
          _section('Android detectors (${androidDetectors.length})', androidDetectors),
          _section('iOS detectors (${iosDetectors.length})', iosDetectors),
        ],
      ),
    );
  }

  Widget _actionRow(ThreatCategory category, AppliedConfig? applied) {
    final effective = applied?.policies[category];
    final clamped = effective != null && effective != _requested[category];
    return Row(
      children: [
        Expanded(child: Text(category.value)),
        DropdownButton<ThreatAction>(
          value: _requested[category],
          items: [for (final a in ThreatAction.values) DropdownMenuItem(value: a, child: Text(a.value))],
          onChanged: (value) => setState(() => _requested[category] = value!),
        ),
        SizedBox(
          width: 96,
          child: Text(
            effective == null ? '' : '-> ${effective.value}${clamped ? ' *' : ''}',
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<DetectorEntry> entries) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          for (final entry in entries)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entry.id),
              subtitle: Text(entry.tier == Tier.exp ? 'exp (forced REPORT)' : 'prod'),
              value: _detectors[entry.id] ?? true,
              onChanged: (value) => setState(() => _detectors[entry.id] = value),
            ),
        ],
      );
}
