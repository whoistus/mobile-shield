# Support matrix

Release commitments. Anything not listed is best effort.

## Versions

| Area | Commitment |
|---|---|
| React Native | 0.72 (old architecture); 0.86 (New Architecture only, classic NativeModule through the interop layer) |
| Flutter | 3.27+ (Dart SDK >= 3.6.0), CocoaPods and SwiftPM hosts, add-to-app |
| Gradle / AGP | AGP 8.5.1+ with a Gradle version supported by that AGP; Gradle centralized repositories (`FAIL_ON_PROJECT_REPOS`) supported |
| Android | minSdk 21, compileSdk 35, ABIs arm64-v8a, armeabi-v7a, x86, x86_64, NDK r28, all ELF LOAD segments 16KB aligned |
| iOS | 13.0+, Xcode 26.6, XCFramework slices ios-arm64 and ios-arm64_x86_64-simulator |

Interop-layer removal in React Native is the trigger for a TurboModule rewrite.

## Consumer packaging matrix

Each host links the stub core and prints `sdkVersion`; CI job `consumers.yml` builds them all. Static vs dynamic XCFramework is decided from these results and recorded here.

| Host | Directory | Status |
|---|---|---|
| RN 0.72, default Podfile | consumers/rn-072 `ios-default` | PASS (simulator logs sdkVersion; rebuilt before the Swift-linkage fix) |
| RN 0.72, `use_frameworks! :linkage => :static` | consumers/rn-072 `ios-static` | PASS (simulator logs sdkVersion) |
| RN 0.86, New Architecture (interop) | consumers/rn-086 `android`, `ios` | NOT VERIFIED (deferred to final verification) |
| Flutter 3.27, CocoaPods | consumers/flutter-app `ios-cocoapods` | PASS (simulator logs sdkVersion) |
| Flutter 3.27, SwiftPM | consumers/flutter-app `ios-spm` | PASS (simulator logs sdkVersion) |
| Flutter module to `flutter build aar`, separate native Android host | consumers/flutter-module + consumers/android-host | PASS (build + 16KB) |
| Android host with Gradle centralized repositories | consumers/android-host (`FAIL_ON_PROJECT_REPOS`) | PASS (build + 16KB) |

Token-based GitHub Packages resolution (Maven and npm) is unverified until the remote repository exists. Until then CI and local runs resolve the core from `mavenLocal()`.

## Decisions from matrix results

- XCFramework linkage: **static** (`MACH_O_TYPE=staticlib`). RN CLI apps link pods statically by default and the static framework worked in every iOS host (RN default + static Podfile, Flutter CocoaPods + SwiftPM). The ObjC facade calls internal Swift so ObjC-only hosts link the Swift objects.
- RN 0.72 Android: SDK libs are 16KB-aligned; RN 0.72's own libs are not (out of scope). Consumer gate uses `check-16kb.sh --only libmobileshield`.
- On-device Android JNI proof: instrumented test `MobileShieldInstrumentedTest` runs in CI job `android-16k-smoke` (16 KB emulator); not run locally.
