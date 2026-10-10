# Support matrix

Release commitments. Anything not listed is best effort.

## Versions

| Area | Commitment |
|---|---|
| React Native | 0.72 (old architecture); 0.86 (New Architecture only, classic NativeModule through the interop layer) |
| Flutter | 3.27+ (Dart SDK >= 3.6.0), CocoaPods and SwiftPM hosts, add-to-app |
| Gradle / AGP | AGP 8.5.1+ with a Gradle version supported by that AGP; Gradle centralized repositories (`FAIL_ON_PROJECT_REPOS`) supported |
| Android | minSdk 21, compileSdk 35, ABIs arm64-v8a, armeabi-v7a, x86, x86_64, NDK r28, 64-bit ELF LOAD segments 16KB aligned (`libmobileshield` is 16KB aligned on all 4 ABIs; RootBeer's 32-bit `libtoolChecker.so` is 4KB, which 16KB devices never load) |
| iOS | 13.0+, Xcode 26.6, XCFramework slices ios-arm64 and ios-arm64_x86_64-simulator |

Interop-layer removal in React Native is the trigger for a TurboModule rewrite.

## Consumer packaging matrix

Hosts under `consumers/` link the real core and print `sdkVersion`; CI job `consumers.yml` builds them (also run from `release.yml`). Static vs dynamic XCFramework is decided from these results and recorded below. "Compile-verified" means built (and for iOS, launched on a simulator where noted); nothing here has run on a physical or rooted device.

| Host | Directory | Status |
|---|---|---|
| RN 0.72, default Podfile | consumers/rn-072 `ios-default` | compile-verified (simulator build links) |
| RN 0.72, `use_frameworks! :linkage => :static` | consumers/rn-072 `ios-static` | compile-verified |
| RN 0.72, Android | consumers/rn-072 `android` | compile-verified (release APK, SDK libs 16KB aligned) |
| RN 0.86, New Architecture (interop) | consumers/rn-086 `android`, `ios` | Android debug assembly passed locally earlier; iOS and full gate NOT VERIFIED |
| Flutter 3.27, CocoaPods | consumers/flutter-app `ios-cocoapods` | compile-verified |
| Flutter 3.27, SwiftPM | consumers/flutter-app `ios-spm` | compile-verified (simulator) |
| Flutter 3.27, Android | consumers/flutter-app `android` | compile-verified |
| Flutter module to `flutter build aar`, separate native Android host | packages/flutter/example_module + example_host (also consumers/flutter-module + android-host) | compile-verified (release build + 16KB check) |
| Android host with Gradle centralized repositories | consumers/android-host (`FAIL_ON_PROJECT_REPOS`) | compile-verified |

## Example apps

| App | Path | What it shows | Status |
|---|---|---|---|
| RN example (RN 0.72) | packages/react-native/example | `ShieldGate` root gate, Environment / Events / Remote config screens | `tsc` and bridge compile (via consumers/rn-072); not launched on a device in this phase |
| Flutter example | packages/flutter/example | `ShieldController`, config screen with all detector ids | `flutter analyze`, `flutter build apk`, iOS CocoaPods and SwiftPM simulator builds |
| Flutter add-to-app | packages/flutter/example_module + example_host | module AAR consumed by a native Android host | release build of the host |

Token-based GitHub Packages resolution (Maven and npm) is unverified until the remote repository and a first publish exist. Until then CI and local runs resolve the core from `mavenLocal()`.

## Decisions from matrix results

- XCFramework linkage: **static** (`MACH_O_TYPE=staticlib`). RN CLI apps link pods statically by default and the static framework worked in every iOS host (RN default + static Podfile, Flutter CocoaPods + SwiftPM). The ObjC facade calls internal Swift so ObjC-only hosts link the Swift objects.
- RN 0.72 Android: SDK libs are 16KB-aligned; RN 0.72's own libs are not (out of scope). Consumer gate uses `check-16kb.sh --only libmobileshield`.
- On-device Android JNI proof: instrumented tests (`SmokeInstrumentedTest`, `EnvironmentProbeTest`) run in CI job `android-16k-smoke` (16 KB emulator); not run locally.
