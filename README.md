# mobile-shield

In-house mobile security SDK for Android and iOS with thin React Native and Flutter wrappers: root and jailbreak, emulator, debugger, hooking, tampering and environment checks. Policy-driven (REPORT / WARN / BLOCK / KILL) instead of killing the process on the first hit. No dependency on Google or Huawei services.

Internal use only. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Report findings per [SECURITY.md](SECURITY.md).

## Status

0.1.0 development snapshot. Android core, iOS core, the React Native wrapper and the Flutter plugin are implemented and compile-verified. Not released, not calibrated on real rooted/jailbroken/non-GMS devices, wallet migration pending. Details: [docs/implementation-status.md](docs/implementation-status.md).

## What it does and does not do

- 39 detector ids (Android 22, iOS 17) in 10 categories, tiered: 25 production, 14 experimental (forced to REPORT until promoted).
- The SDK decides; **your app enforces**. BLOCK sets a native sticky flag. Gate every protected operation on native `isBlocked()`. Device-side only: no backend leg, no attestation yet.
- Not covered: attestation, SSL pinning, malware/overlay detection, a determined attacker with full device control. See [docs/threat-model.md](docs/threat-model.md).

## Integrate

| You are | Start here |
|---|---|
| React Native (0.72, 0.86) | [docs/integration-rn.md](docs/integration-rn.md) |
| Flutter 3.27+ | [docs/integration-flutter.md](docs/integration-flutter.md) |
| Getting a read token, CI secrets | [docs/consumer-setup.md](docs/consumer-setup.md) |
| Tuning detectors, remote config, signing | [docs/runtime-config.md](docs/runtime-config.md) |
| Non-GMS fleets | [docs/non-gms-devices.md](docs/non-gms-devices.md) |
| Supported versions and verified hosts | [docs/support-matrix.md](docs/support-matrix.md) |
| Per-detector specs | [docs/detectors/](docs/detectors/) |

Publishers: [docs/release-setup.md](docs/release-setup.md), [docs/release-provenance.md](docs/release-provenance.md). Nothing is published yet.

## Layout

```
core-android/            Gradle project, :core library (Java facade + C++)
core-ios/                Xcode project MobileShieldCore (ObjC public header)
packages/react-native/   @whoistus/react-native-mobile-shield (+ example/)
packages/flutter/        mobile_shield (+ example/, example_module/, example_host/)
consumers/               packaging-matrix sample hosts (built by CI, never published)
scripts/                 build, 16KB check, version check, sync, forbidden-string check
docs/                    guides, threat model, specs
VERSION                  single source of truth (lockstep versions)
```

## Build

```bash
./scripts/build-aar.sh                         # Android AAR (4 ABIs), unit tests, Maven Local
./scripts/check-16kb.sh <apk|aab|aar>          # every native lib LOAD align >= 0x4000
./scripts/build-xcframework.sh                 # core-ios/build/MobileShieldCore.xcframework
./scripts/sync-binaries.sh                     # copy xcframework into wrappers, stamp VERSION, check versions
./scripts/check-versions.sh [vX.Y.Z]           # VERSION, wrappers, podspecs, Package.swift (and tag) agree
./scripts/check-forbidden-strings.sh           # repo hygiene gate
```

CI: `build-core.yml` (core build and checks), `consumers.yml` (packaging matrix), `release.yml` (tag `v*`: version check, both of the above, Maven, npm, GitHub Release).
