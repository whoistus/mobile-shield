import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_shield/mobile_shield.dart';
import 'package:mobile_shield_example/main.dart';
import 'package:mobile_shield_example/shield_controller.dart';

int _lastSeq = 0;

// Native persists the last accepted seq across runs (and the example app uses epoch seconds),
// so a fixed seq would be rejected on a rerun. init is idempotent, so every test can call it.
Future<EnvironmentInfo> _init() {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  _lastSeq = now > _lastSeq ? now : _lastSeq + 1;
  return MobileShield.init({'version': 1, 'appId': exampleAppId, 'seq': _lastSeq});
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('init returns EnvironmentInfo and the native version', (tester) async {
    final info = await _init();
    expect(info.sdkVersion, isNotEmpty);
    expect(info.platform, anyOf('android', 'ios'));
    expect(await MobileShield.sdkVersion(), info.sdkVersion);
  });

  testWidgets('runChecks and getConfig answer after init', (tester) async {
    await _init();
    final events = await MobileShield.runChecks();
    expect(events, isA<List<ThreatEvent>>());
    final config = await MobileShield.getConfig();
    expect(config.channel, isNotEmpty);
    expect(await MobileShield.isBlocked(), isA<bool>());
  });

  testWidgets('example app renders either the gate or the home screen', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Mobile Shield').evaluate().isNotEmpty ||
        find.textContaining('blocked').evaluate().isNotEmpty, isTrue);
  });
}
