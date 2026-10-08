# mobile-shield

In-house mobile security SDK: root/jailbreak, emulator, debugger, hooking, tampering and environment checks for Android and iOS, with thin React Native and Flutter wrappers. Policy-driven (REPORT / WARN / BLOCK / KILL) instead of killing the process on first hit. No dependency on Google or Huawei services.

Internal use only. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Status

0.1.0 scaffold (phase 1): hello-world cores, build and packaging pipeline, docs. No detectors yet; `getSdkVersion()` only.

## Scope

- 39 detectors in 10 threat categories, tiered (production vs experimental). See [docs/threat-model.md](docs/threat-model.md).
- Not covered: device attestation (deferred), SSL pinning, malware/overlay detection, backend enforcement.
- Supported hosts and versions: [docs/support-matrix.md](docs/support-matrix.md).

## Layout

```
core-android/            Gradle project, :core library (Java facade + C++)
core-ios/                Xcode project MobileShieldCore (ObjC public header)
packages/react-native/   @whoistus/react-native-mobile-shield
packages/flutter/        mobile_shield
consumers/               packaging-matrix sample hosts (built by CI, never published)
scripts/                 build, 16KB check, sync, forbidden-string check
docs/                    threat model, support matrix, setup guides
VERSION                  single source of truth (lockstep versions)
```

## Getting a read token

The Android core is on GitHub Packages Maven and the RN wrapper on GitHub Packages npm. Both need a token even for reads. Follow [docs/consumer-setup.md](docs/consumer-setup.md). Publishers: [docs/release-setup.md](docs/release-setup.md).

## Build

```bash
./scripts/build-aar.sh                         # Android AAR (4 ABIs)
./scripts/check-16kb.sh <apk|aab|aar>          # every native lib LOAD align >= 0x4000
./scripts/build-xcframework.sh                 # core-ios/build/MobileShieldCore.xcframework
./scripts/sync-binaries.sh                     # copy xcframework into wrappers, stamp VERSION
./scripts/check-forbidden-strings.sh           # repo hygiene gate
```

CI: `.github/workflows/build-core.yml` (core build + checks) and `consumers.yml` (packaging matrix).
