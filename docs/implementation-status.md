# Implementation status (0.1.0 development snapshot, 2026-10-10)

Phases 2-5 are implemented in code and compile-verified. Nothing is released, nothing is device-verified, and phase 6 (wallet migration) is intentionally skipped for now. Treat this as a reviewable snapshot, not a release candidate.

## Phase status

| Phase | State |
|---|---|
| 1 Scaffold, licensing, CI spike | done (commit 0964109) |
| 2 Android core | implemented, compile-verified; tests written, not run as a recorded gate; device matrix pending |
| 3 iOS core | implemented, compile-verified; tests written, not run as a recorded gate; device matrix pending |
| 4 React Native wrapper + example | implemented, compile-verified |
| 5 Flutter plugin + example, module, host | implemented, compile-verified |
| 6 Wallet migration | skipped (pending); the wallet keeps its existing checks |
| 7 Docs, notices, release workflow | docs, notices and `release.yml` written; `release.yml` has never run; nothing published |

## What exists

- Android: bootstrap from manifest meta-data, runtime config pipeline (signature, schema, seq/expiry, merge, floor), Ed25519 verification (Tink), last-known-good persistence, native policy engine with sticky block flag, watchdog, listeners, foreground monitoring, environment probe, all 22 registry ids present (14 prod, 8 experimental).
- iOS: Info.plist bootstrap, same config pipeline with CryptoKit, last-known-good persistence, policy, watchdog, foreground monitoring, 17 registry ids (11 prod, 6 experimental) including `tampering.teamId` (keychain access group, else provisioning profile; unsupported on the simulator or without `MobileShieldTeamId`).
- React Native: typed JS API, Android and iOS bridges, `ShieldGate` example. Flutter: Dart API with typed exceptions, Android and iOS plugins (CocoaPods and SwiftPM), example app, add-to-app module and host.
- Attestation: `unsupported` everywhere by design.

## Compile verification (commands)

| Platform | Command | What it proves |
|---|---|---|
| Android core | `./scripts/build-aar.sh` (unit tests, `assembleRelease`, Maven Local) | AAR with 4 ABIs: arm64-v8a, armeabi-v7a, x86, x86_64 |
| | `./scripts/check-16kb.sh core-android/core/build/outputs/aar/core-release.aar` | every 64-bit (arm64-v8a, x86_64) ELF LOAD segment aligned to >= 0x4000; 32-bit libs listed as INFO |
| | exported-symbol inspection of `libmobileshield.so` | only `JNI_OnLoad` exported (reported by the phase 2 run; no script in the repo enforces it) |
| iOS core | `xcodebuild build-for-testing` on `MobileShieldCore` (simulator) | core and test targets compile |
| | `./scripts/build-xcframework.sh`, then `./scripts/sync-binaries.sh` | device and simulator slices; identical copy in both wrappers |
| React Native | `npm run typecheck` in `packages/react-native` | `tsc --noEmit` clean |
| | `consumers/rn-072/build.sh android`, `ios-default`, `ios-static` | the Java and ObjC bridges compile and link against the core |
| Flutter | `flutter analyze` in `packages/flutter` | Dart API analysis |
| | `flutter build apk` in `packages/flutter/example` | Android plugin links the core |
| | `consumers/flutter-app/build.sh ios-cocoapods`, `ios-spm` | iOS plugin links (simulator) under both package managers |
| | `packages/flutter/example_host/build.sh` | add-to-app: module AAR plus native host, release build |
| Release plumbing | `bash -n scripts/*.sh`, `scripts/check-versions.sh`, workflow YAML parse | scripts parse, versions agree; workflows not executed |

Unit tests exist for config (merge, floor, signature, shared vectors in `scripts/fixtures/config-vectors.json`), policy, selected detectors, engine and monitor (Android JVM tests, iOS XCTest, RN jest, Flutter widget/unit tests). A passing full run on both platforms is not recorded in this snapshot.

## Not done

- Device matrix ([test-matrix.md](test-matrix.md)) on rooted, rootless-jailbroken, non-GMS, OEM and 16KB devices: not executed. Detector tiers and confidence values are provisional until it is.
- On-device JNI smoke test: written (`SmokeInstrumentedTest`), runs only in CI job `android-16k-smoke`.
- RFC 8785 canonicalizer conformance: no independent review; shared vectors not yet run on both platforms.
- Android has no list of unsupported detectors (iOS exposes `getConfig().unsupportedDetectors`). A detector that is unsupported emits nothing, so event absence is never proof of a clean device. Detector specs under `docs/detectors/` describe target behaviour and do not assert a detector is active.
- Consumers: RN 0.86 iOS, Flutter iOS add-to-app, clean installs from the registry and device launches are untested.
- Registry publishing: no rc or final package exists; `release.yml` untested; GitHub Packages Maven and npm access with a read token unverified.
- Release gates: written company ownership sign-off, device calibration, report-only observation (>= 1 week or >= 500 sessions) of an rc in one real app.
- Code review 2026-10-10 (7/10) fixes applied: iOS `policy.*` WARN cap, jailbreak detectors unsupported on iOS-app-on-Mac / Catalyst, iOS init/config-apply serialised, JNI entry points catch C++ exceptions, NaN `blockThreshold` rejected natively, RN iOS `getConfig`/`startMonitoring` reject `NotInitialized`. Codex implementation review 2026-10-10 fixes applied: RootBeer scored per check (test-keys excluded), Android config generation serialised with check cycles and committed before policy events, strict Android config schema (+18 shared vectors), JNI double/int64 with kill delay capped at 60 s, `attachActivity` + RN/Flutter wiring, 64-event backlog, RN example readiness, iOS listener test, Flutter smoke test seq. Open decisions: plan.md § Open decisions.

## Local test run on 2026-10-10

- Android JVM unit tests: 90/90 passed (`./gradlew :core:testReleaseUnitTest`), including all shared config vectors.
- Native host googletest: 38/38 passed (`scripts/test-native-host.sh`; `enable_testing()` was missing, so ctest previously registered no tests).
- iOS XCTest on the iPhone 17 simulator: 107/107 passed, including all shared config vectors.
- React Native jest: 19/19 passed. Flutter `flutter test`: 18/18 passed.
- Android instrumented tests on the `Medium_Phone_API_37.0` emulator (arm64, API 37): 16/16 passed; `runChecks` averaged 249 ms (worst 502 ms).
- Not run: example and consumer app launches, Flutter integration test, RN 0.86 iOS, 16KB emulator image, and the physical device matrix.

## CI on main (2026-10-10)

First pushes to `main` failed every job before any build ran. Fixes:

- `android-actions/setup-android@v3` installs `tools platform-tools` by default; the legacy `tools` package is gone from the SDK repository. All workflows now pass `packages: platform-tools` (commit 5db3ffa). After this `build-core` / `build` passed: forbidden strings, native host tests, AAR + unit tests, 16KB AAR gate, iOS unit tests, XCFramework, sync.
- `android-16k-smoke`: the emulator exited with `FATAL | Not enough space to create userdata partition` (needs 7.37 GB, runner had 6.31 GB). The job now frees runner disk first.
- `consumers / android-host`: `check-16kb.sh` failed on RootBeer 0.1.1's `armeabi-v7a` and `x86` `libtoolChecker.so` (0x1000). 16KB page-size devices only run 64-bit code, so the script now gates arm64-v8a and x86_64 and lists 32-bit libs as `INFO-*`. RootBeer's 64-bit libs are 0x4000. Verified locally against synthetic APKs (32-bit 4KB lib: PASS; 64-bit 4KB lib: FAIL; `--only` still scopes the gate).
- `build-core / build`: `WatchdogTests.testKillActionSchedulesWatchdogAndStopMonitoringDoesNotCancelIt` timed out once (2 s wait for a 30 ms kill; the test took 10.8 s, so the simulator stalled). Passed on the previous commit with identical iOS code. Fire waits raised to 10 s and the harness is kept alive across the wait (the kill reaches it through a weak reference). Not run locally (no Swift toolchain in the Linux session); CI verifies.
- `consumers / rn-072 (android)`: `aapt2` (AGP 7.4, RN 0.72) failed to load the current `platforms/android-35/android.jar` while building the RN wrapper module. The wrapper now uses the host's `compileSdkVersion` (`safeExtGet`, fallback 35), the usual RN library convention.
- `consumers / rn-072 (ios-default, ios-static)`: link failed on `__swift_FORCE_LOAD_$_swiftCompatibility56` (YogaKit and MobileShieldCore). On the Xcode 26.6 runner `$(TOOLCHAIN_DIR)` resolves to the Metal toolchain, so the RN 0.72 template's Swift library search path is wrong. `rn-072` and the RN example now use `$(DT_TOOLCHAIN_DIR)`. RN 0.72 hosts on Xcode 26 with the Metal toolchain need the same change.
- `consumers / flutter-app (ios-spm)`: the launch check missed `sdkVersion=` once after a 3-minute simulator boot; it passed on 5db3ffa. The wait is now 90 s with a `log show` fallback.
