# Flutter integration

Package `mobile_shield` (Flutter 3.27+, Dart >= 3.6.0), delivered as a git dependency from this private repository. MethodChannel `mobile_shield` plus EventChannel `mobile_shield/threats`. Snippets come from `packages/flutter/example` (full app), `example_module` + `example_host` (add-to-app) and `consumers/flutter-app`. What has been run: [implementation-status.md](implementation-status.md).

## 1. Install

Git access uses your normal GitHub credentials. Pin a tag; `path` is required because the plugin lives in a subdirectory.

```yaml
# pubspec.yaml
dependencies:
  mobile_shield:
    git:
      url: https://github.com/whoistus/mobile-shield.git
      path: packages/flutter
      ref: vX.Y.Z   # exact release tag; no tag is published yet
```

For local work in a checkout: `mobile_shield: {path: ../mobile-shield/packages/flutter}`. The package is `publish_to: none`.

Android also needs the private Maven repository for `io.mobileshield:core` (the plugin pins the exact version). Flutter app (`android/build.gradle`):

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://maven.pkg.github.com/whoistus/mobile-shield")
            credentials {
                username = findProperty("gpr.user") ?: System.getenv("GITHUB_ACTOR")
                password = findProperty("gpr.token") ?: System.getenv("GITHUB_TOKEN")
            }
            content { includeGroup("io.mobileshield") }
        }
    }
}
```

Hosts using Gradle centralized repositories use the `settings.gradle` block in [consumer-setup.md](consumer-setup.md). minSdk 21, compileSdk 35, AGP 8.5.1+.

iOS (13.0+): CocoaPods works with no extra steps (`mobile_shield.podspec` vendors the XCFramework). SwiftPM: `flutter config --enable-swift-package-manager`; the plugin ships `ios/mobile_shield/Package.swift` with a binary target on the same XCFramework.

## 2. Bootstrap values (native, immutable)

Same keys as React Native, in the app's own bundle: `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`. Copy the blocks from [integration-rn.md section 2](integration-rn.md#2-bootstrap-values-native-immutable): `io.mobileshield.CHANNEL`, `io.mobileshield.CONFIG_PUBKEY`, `io.mobileshield.SIGNING_SHA256`; `MobileShieldChannel`, `MobileShieldConfigPubKey`, `MobileShieldTeamId`, optional `MobileShieldBundleId` and `MobileShieldDistribution`; and `LSApplicationQueriesSchemes` with `cydia`, `sileo`, `zbra`, `filza`, `undecimus` (without them `jailbreak.urlSchemes` is unsupported). The example uses channel `dev` in both files.

## 3. Initialise, listen, gate

`ShieldController` in `packages/flutter/example/lib/shield_controller.dart` (abridged). Listen to `threats` before `init`; native delivery starts with the first listener, and events raised before it (at most 64, from init's first pass) are replayed to it. The plugin passes the current activity to the SDK (`ActivityAware`) so lifecycle and screenshot detection work when `init` runs mid-session.

```dart
import 'package:mobile_shield/mobile_shield.dart';

// Must equal the Android applicationId and the iOS bundle id (checked natively).
const appId = 'com.example.app';

final sub = MobileShield.threats.listen((ThreatEvent e) {
  // Native owns enforcement; ask it instead of reading e.action.
  MobileShield.isBlocked().then((blocked) { if (blocked) showBlocked(); });
});

EnvironmentInfo? info;
try {
  info = await MobileShield.init(signedConfig);   // dev: {'version': 1, 'appId': appId, 'seq': epochSeconds}
} on ConfigRejectedException catch (e) {
  // SDK is initialised on defaults / last-known-good (floor: clamped config is active); see e.reason
} on MobileShieldException catch (e) {
  // NativeUnavailable, BootstrapMissing, ...: fail closed
}
// Fail closed: if init failed natively, do not render the protected app.
final blocked = info == null ? true : await MobileShield.isBlocked();
if (!blocked) await MobileShield.startMonitoring();
```

Gate rules are the same as React Native: call `MobileShield.isBlocked()` before every protected operation (root widget, deep links, restored sessions, push-opened routes); the flag is native, sticky for the process, and `isBlocked()` returns `true` if the channel gives no answer. Monitoring is foreground only. Several engines share one native instance; when the last stream listener cancels, delivery stops.

API (`lib/mobile_shield.dart`): `init`, `updateConfig`, `getConfig`, `runChecks`, `startMonitoring`, `stopMonitoring`, `isBlocked`, `attestEnrol`, `attestAssert`, `sdkVersion()`, `threats`. `updateConfig` takes a full config (same shape as `init`, despite the parameter name); omitted fields revert to channel defaults. Attestation returns `AttestationResult(status: 'unsupported')`, it does not throw.

## 4. Types

- `ThreatAction` (`report`, `warn`, `block`, `kill`) is the Dart name of the native `Action`, renamed because it would clash with Flutter's `Action` widget. Other enums: `ThreatCategory` (`root`, `emulator`, `debugger`, `hooking`, `tampering`, `installer`, `screenCapture`, `devOptionsAdb`, `noDeviceLock`, `vpnProxy`) and `Severity`. `.value` is the wire string (`'BLOCK'`).
- `ThreatEvent`: `category`, `severity`, `confidence`, `detectorId`, `action`, `timestamp` (epoch ms), `platform`, `details`, `isBlocking`.
- `EnvironmentInfo`: `sdkVersion`, `platform`, `osVersion`, `abi`, `isDebuggable`, `gmsAvailable`, `hmsAvailable`, `installer` (nullable), `attestationKinds` (always empty).
- `AppliedConfig`: `channel`, `policies`, `disabled`, `unsupportedDetectors` (iOS only), `blockThreshold`, `monitoringIntervalMs`, `killDelayMsRange`, `installerAllowlist`, `seq`, `clamped`, `isEnabled(id)`.

## 5. Errors

Subclasses of `MobileShieldException` (`.code`, `.message`): `NativeUnavailableException` (also when the plugin is missing), `NotInitializedException`, `BootstrapMissingException`, `ConfigRejectedException` (`.reason`: `ConfigRejectedReason.signature | floor | schema | expired`), `DetectorUnsupportedException`, `AttestationUnsupportedException` (the last two are reserved; native never throws them today). Semantics of `init` with a rejected config are identical to React Native: the SDK is initialised; `signature`/`schema`/`expired` apply nothing (defaults or last-known-good stay); `floor` applies and persists the clamped config. Always read `getConfig()` afterwards, as `pushConfig` does in the example. See [integration-rn.md section 5](integration-rn.md#5-errors) for the full table.

## 6. Add-to-app (Flutter module in a native host)

`packages/flutter/example_module` is a Flutter module depending on `mobile_shield: {path: ../}`; `packages/flutter/example_host` is a native Android host. The bootstrap `<meta-data>` entries go in the host app's manifest (`example_host/app/src/main/AndroidManifest.xml`), and the runtime `appId` is the host's applicationId (`io.mobileshield.example.host` in the example).

```bash
cd packages/flutter/example_module && flutter pub get && flutter build aar --no-debug --no-profile
```

Host `settings.gradle` repositories (works with `FAIL_ON_PROJECT_REPOS`):

```groovy
def moduleRepo = new File(settingsDir, "../example_module/build/host/outputs/repo").canonicalFile
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri(moduleRepo) }
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        maven {
            url = uri("https://maven.pkg.github.com/whoistus/mobile-shield")
            credentials {
                username = settings.providers.gradleProperty("gpr.user").orNull ?: System.getenv("GITHUB_ACTOR")
                password = settings.providers.gradleProperty("gpr.token").orNull ?: System.getenv("GITHUB_TOKEN")
            }
            content { includeGroup("io.mobileshield") }
        }
    }
}
```

The example also lists `mavenLocal()` for development only; remove it to exercise the real registry. `packages/flutter/example_host/build.sh` builds the AAR, then the host in release with a fresh Gradle cache and runs the 16KB check. iOS add-to-app (Flutter module embedded in a native iOS host) has not been built.
