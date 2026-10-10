import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_shield/mobile_shield.dart';

const _channel = MethodChannel('mobile_shield');
const _events = EventChannel('mobile_shield/threats');

const _envJson = {
  'sdkVersion': '0.1.0',
  'platform': 'android',
  'osVersion': '14',
  'abi': 'arm64-v8a',
  'isDebuggable': false,
  'gmsAvailable': true,
  'hmsAvailable': false,
  'installer': null,
  'attestationKinds': <String>[],
};

const _eventJson = {
  'category': 'SCREEN_CAPTURE',
  'severity': 'LOW',
  'confidence': 0.9,
  'detectorId': 'screen.captured',
  'action': 'WARN',
  'timestamp': 1760000000000,
  'platform': 'android',
  'details': {'k': 'v'},
};

const _configJson = {
  'channel': 'prod',
  'policies': {'ROOT': 'BLOCK', 'TAMPERING': 'WARN'},
  'disabled': ['hooking.fridaFd'],
  'unsupportedDetectors': ['tampering.teamId'],
  'blockThreshold': 0.7,
  'monitoringIntervalMs': 5000,
  'killDelayMsRange': [500, 3000],
  'installerAllowlist': ['com.android.vending'],
  'seq': 3,
  'clamped': ['policies.TAMPERING'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];

  void mock(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(_channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);
  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    messenger.setMockStreamHandler(_events, null);
  });

  group('calls', () {
    test('init forwards config untouched and parses EnvironmentInfo', () async {
      mock((_) async => jsonEncode(_envJson));
      final config = {
        'version': 1,
        'appId': 'io.example',
        'seq': 1,
        'policies': {'ROOT': 'BLOCK'},
        'detectors': {'root.suPaths': false},
        'killDelayMsRange': [500, 3000],
      };

      final info = await MobileShield.init(config);

      expect(calls.single.method, 'init');
      expect(calls.single.arguments, config);
      expect(info.sdkVersion, '0.1.0');
      expect(info.platform, 'android');
      expect(info.gmsAvailable, isTrue);
      expect(info.installer, isNull);
      expect(info.attestationKinds, isEmpty);
    });

    test('updateConfig forwards the partial and parses AppliedConfig', () async {
      mock((_) async => jsonEncode(_configJson));

      final applied = await MobileShield.updateConfig({'seq': 4});

      expect(calls.single.method, 'updateConfig');
      expect(calls.single.arguments, {'seq': 4});
      expect(applied.policies[ThreatCategory.root], ThreatAction.block);
      expect(applied.disabled, ['hooking.fridaFd']);
      expect(applied.isEnabled('hooking.fridaFd'), isFalse);
      expect(applied.unsupportedDetectors, ['tampering.teamId']);
      expect(applied.killDelayMsRange, [500, 3000]);
      expect(applied.clamped, ['policies.TAMPERING']);
    });

    test('getConfig tolerates a missing unsupportedDetectors key', () async {
      final json = Map<String, Object?>.of(_configJson)..remove('unsupportedDetectors');
      mock((_) async => jsonEncode(json));

      final applied = await MobileShield.getConfig();

      expect(calls.single.method, 'getConfig');
      expect(applied.unsupportedDetectors, isEmpty);
    });

    test('runChecks parses a list of ThreatEvent', () async {
      mock((_) async => jsonEncode([_eventJson]));

      final events = await MobileShield.runChecks();

      expect(events, hasLength(1));
      final event = events.single;
      expect(event.category, ThreatCategory.screenCapture);
      expect(event.severity, Severity.low);
      expect(event.action, ThreatAction.warn);
      expect(event.confidence, 0.9);
      expect(event.timestamp, 1760000000000);
      expect(event.details, {'k': 'v'});
      expect(event.isBlocking, isFalse);
    });

    test('monitoring, isBlocked, sdkVersion', () async {
      mock((call) async => switch (call.method) {
            'isBlocked' => true,
            'getSdkVersion' => '0.1.0',
            _ => null,
          });

      await MobileShield.startMonitoring();
      await MobileShield.stopMonitoring();

      expect(await MobileShield.isBlocked(), isTrue);
      expect(await MobileShield.sdkVersion(), '0.1.0');
      expect(calls.map((c) => c.method),
          ['startMonitoring', 'stopMonitoring', 'isBlocked', 'getSdkVersion']);
    });

    test('isBlocked fails closed on a null answer', () async {
      mock((_) async => null);
      expect(await MobileShield.isBlocked(), isTrue);
    });

    test('attestation passes arguments and reports unsupported', () async {
      mock((_) async => jsonEncode({'status': 'unsupported', 'kind': 'play'}));

      final enrol = await MobileShield.attestEnrol('play', 'n1');
      final assertion = await MobileShield.attestAssert('play', 'n1', 'h1');

      expect(calls[0].arguments, {'kind': 'play', 'nonce': 'n1'});
      expect(calls[1].arguments,
          {'kind': 'play', 'nonce': 'n1', 'requestHash': 'h1'});
      expect(enrol.isUnsupported, isTrue);
      expect(assertion.kind, 'play');
    });
  });

  group('enums', () {
    test('wire values match the design contract', () {
      expect(ThreatCategory.values.map((e) => e.value), [
        'ROOT', 'EMULATOR', 'DEBUGGER', 'HOOKING', 'TAMPERING', 'INSTALLER',
        'SCREEN_CAPTURE', 'DEV_OPTIONS_ADB', 'NO_DEVICE_LOCK', 'VPN_PROXY',
      ]);
      expect(ThreatAction.values.map((e) => e.value), ['REPORT', 'WARN', 'BLOCK', 'KILL']);
      expect(Severity.values.map((e) => e.value), ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']);
    });

    test('unknown values are rejected', () {
      expect(() => ThreatAction.fromValue('EXPLODE'), throwsFormatException);
    });
  });

  group('error mapping', () {
    Future<Object> failWith(PlatformException error, Future<void> Function() call) async {
      mock((_) async => throw error);
      try {
        await call();
      } catch (e) {
        return e;
      }
      fail('expected a throw');
    }

    test('NotInitialized', () async {
      final e = await failWith(PlatformException(code: 'NotInitialized', message: 'call init first'),
          MobileShield.getConfig);
      expect(e, isA<NotInitializedException>());
      expect((e as MobileShieldException).message, 'call init first');
    });

    test('BootstrapMissing and NativeUnavailable', () async {
      expect(await failWith(PlatformException(code: 'BootstrapMissing'), MobileShield.getConfig),
          isA<BootstrapMissingException>());
      expect(await failWith(PlatformException(code: 'NativeUnavailable'), MobileShield.getConfig),
          isA<NativeUnavailableException>());
    });

    test('ConfigRejected carries the reason from details', () async {
      for (final reason in ConfigRejectedReason.values) {
        final e = await failWith(
            PlatformException(code: 'ConfigRejected', details: {'reason': reason.name}),
            () => MobileShield.updateConfig({'seq': 1}));
        expect(e, isA<ConfigRejectedException>());
        expect((e as ConfigRejectedException).reason, reason);
      }
    });

    test('ConfigRejected reads a dotted code from a bridge that did not split it', () async {
      final e = await failWith(PlatformException(code: 'ConfigRejected.floor'),
          () => MobileShield.init({}));
      expect((e as ConfigRejectedException).reason, ConfigRejectedReason.floor);
    });

    test('DetectorUnsupported and AttestationUnsupported', () async {
      final d = await failWith(
          PlatformException(code: 'DetectorUnsupported', details: {'id': 'x.y'}),
          MobileShield.runChecks);
      expect((d as DetectorUnsupportedException).id, 'x.y');
      final a = await failWith(
          PlatformException(code: 'AttestationUnsupported', details: {'kind': 'play'}),
          () => MobileShield.attestEnrol('play', 'n'));
      expect((a as AttestationUnsupportedException).kind, 'play');
    });

    test('unknown native code surfaces as the base exception', () async {
      final e = await failWith(PlatformException(code: 'Weird', message: 'm'), MobileShield.getConfig);
      expect(e, isNot(isA<NotInitializedException>()));
      expect((e as MobileShieldException).code, 'Weird');
    });

    test('MissingPluginException becomes NativeUnavailable', () async {
      messenger.setMockMethodCallHandler(_channel, null);
      await expectLater(MobileShield.sdkVersion(), throwsA(isA<NativeUnavailableException>()));
      await expectLater(MobileShield.init({}), throwsA(isA<NativeUnavailableException>()));
    });
  });

  group('threats stream', () {
    test('decodes events and starts/stops native delivery with listeners', () async {
      var listening = false;
      messenger.setMockStreamHandler(
        _events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            listening = true;
            sink.success(jsonEncode(_eventJson));
          },
          onCancel: (arguments) => listening = false,
        ),
      );

      final event = await MobileShield.threats.first;

      expect(event.detectorId, 'screen.captured');
      expect(event.platform, 'android');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(listening, isFalse);
    });

    test('platform errors on the stream are mapped', () async {
      messenger.setMockStreamHandler(
        _events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) =>
              sink.error(code: 'NotInitialized', message: 'call init first'),
        ),
      );

      await expectLater(MobileShield.threats.first, throwsA(isA<NotInitializedException>()));
    });
  });
}
