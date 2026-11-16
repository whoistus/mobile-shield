# Local development: build, pack and link

How to build the SDK from a checkout and use it in an app before (or without) a published release. For consuming a published version see [consumer-setup.md](consumer-setup.md). Toolchain prerequisites (JDK 17 for RN Gradle builds, `ANDROID_HOME`, fvm Flutter 3.27.4, XcodeGen) are in the repository's `CLAUDE.md`.

Local links are for development only. They do not satisfy the clean-install release gate in [consumer-setup.md](consumer-setup.md#clean-install-verification-release-gate).

## What each artifact is and where it comes from

| Artifact | Built by | Local location | Picked up by |
|---|---|---|---|
| Android core `io.mobileshield:core:<VERSION>` | `./scripts/build-aar.sh` | `~/.m2/repository/io/mobileshield/core/<VERSION>/` (also `core-android/build/outputs/core-<VERSION>.aar`) | any Gradle build that lists `mavenLocal()` |
| iOS core `MobileShieldCore.xcframework` | `./scripts/build-xcframework.sh` (macOS + Xcode) | `core-ios/build/` | copied by `./scripts/sync-binaries.sh` into `packages/react-native/ios/Frameworks/` and `packages/flutter/ios/mobile_shield/Frameworks/` |
| RN wrapper `@whoistus/react-native-mobile-shield` | nothing to build (TypeScript source + native module sources) | `packages/react-native` | `file:` link or `npm pack` tarball |
| Flutter plugin `mobile_shield` | nothing to build | `packages/flutter` | pubspec `path:` dependency |

The vendored xcframework copies are committed, so an iOS-only consumer works from a fresh checkout without rebuilding the iOS core, as long as `core-ios` has not changed. Never edit the vendored copies by hand; rebuild and re-sync.

Both wrappers pin the core at exactly `VERSION` (`io.mobileshield:core:<VERSION>` in `packages/*/android/build.gradle`, `s.version` in the podspecs). `sync-binaries.sh` stamps these. If you change `VERSION`, run the full build below so the pins, Maven Local and the vendored framework agree; `./scripts/check-versions.sh` reports any drift.

## 1. Build the cores

From the repository root:

```bash
./scripts/build-aar.sh                                   # Android: unit tests, AAR, publishToMavenLocal
./scripts/build-xcframework.sh && ./scripts/sync-binaries.sh   # iOS (macOS only): build, vendor into both wrappers, stamp VERSION
./scripts/check-versions.sh                              # optional: lockstep VERSION across manifests
```

Skip the iOS line if you only changed Android or wrapper code. `sync-binaries.sh` needs the xcframework from `build-xcframework.sh`, so it cannot run on Linux.

## 2. Make Gradle resolve the core from Maven Local

Put `mavenLocal()` first in the consumer's repositories, before the GitHub Packages block, so a published artifact with the same version does not win:

```groovy
// RN / Flutter app: android/build.gradle
allprojects {
    repositories {
        mavenLocal()          // dev only; remove before release builds
        google()
        mavenCentral()
        maven { url = uri("https://maven.pkg.github.com/whoistus/mobile-shield") /* credentials, see consumer-setup.md */ }
    }
}
```

A native host with centralized repositories puts the same `mavenLocal()` line first in `settings.gradle` `dependencyResolutionManagement { repositories { ... } }` (see `consumers/android-host/settings.gradle`). With `mavenLocal()` and a published-to-Maven-Local core, no GitHub token is needed.

Gradle does not cache artifacts from Maven Local, so re-running `build-aar.sh` with the same version is picked up on the next consumer build. If Android Studio still shows old code, sync Gradle or clean the consumer.

## 3. Link the React Native wrapper

### Option A: `file:` link (apps inside or next to this checkout)

This is what `consumers/rn-072`, `consumers/rn-086` and `packages/react-native/example` do:

```json
"dependencies": {
  "@whoistus/react-native-mobile-shield": "file:../../packages/react-native"
}
```

npm symlinks the package, so JS/TS edits appear on the next Metro reload. Two things are required:

1. **No `node_modules` inside `packages/react-native`.** If you ran `npm ci` there (for `npm test` / `npm run tsc`), delete `packages/react-native/node_modules` before building the app. Otherwise a second copy of `react-native` is resolved and the app fails at runtime or build time.
2. **Metro must watch the package and resolve `react`/`react-native` from the app only.** Copy `consumers/rn-072/metro.config.js`:

```js
const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');
const packageRoot = path.resolve(__dirname, '../../packages/react-native'); // adjust

module.exports = mergeConfig(getDefaultConfig(__dirname), {
  watchFolders: [packageRoot],
  resolver: {
    nodeModulesPaths: [path.resolve(__dirname, 'node_modules')],
    blockList: [new RegExp(`${path.resolve(packageRoot, 'node_modules').replace(/[\\/]/g, '[\\\\/]')}[\\\\/].*`)],
    unstable_enableSymlinks: true,
  },
});
```

The example and consumers install with `npm install --legacy-peer-deps`.

### Option B: `npm pack` tarball (apps outside this checkout)

A tarball has exactly what a registry install would get (the `files` list in `packages/react-native/package.json`: `android` without `build/`, `ios` including the vendored xcframework, `src`, the podspec, LICENSE and notices) and no `node_modules`, so neither the duplicate-`react-native` problem nor the Metro config applies.

```bash
cd packages/react-native
rm -rf node_modules                  # not packed anyway, but keeps the tree clean
npm pack                             # writes whoistus-react-native-mobile-shield-<VERSION>.tgz
cd /path/to/your-app
npm install --save-exact /path/to/mobile-shield/packages/react-native/whoistus-react-native-mobile-shield-<VERSION>.tgz
```

The tarball is a copy: after any change, re-pack and re-install it. Do not commit the `.tgz` or a `file:...tgz` dependency in a product app; switch to the registry version before release.

### Native side

- Android: step 2 (`mavenLocal()` first). The RN module's Java sources compile as part of the app; no extra step.
- iOS: `cd ios && pod install`. The podspec vendors `ios/Frameworks/MobileShieldCore.xcframework`. After re-syncing a new xcframework, run `pod install` again; if Xcode still links the old binary, clean the build folder. iOS 13.0 minimum (raise `platform :ios` on RN 0.72). `MS_LINKAGE=static` in `consumers/rn-072/ios/Podfile` shows the static-linkage variant.

## 4. Link the Flutter plugin

```yaml
dependencies:
  mobile_shield:
    path: ../../packages/flutter     # relative or absolute path to the checkout
```

Then `fvm flutter pub get`. Dart edits appear on hot restart.

- Android: the plugin depends on `io.mobileshield:core:<VERSION>`, so the app's `android/build.gradle` needs `mavenLocal()` first (step 2), and `build-aar.sh` must have run. `consumers/flutter-app/android/build.gradle` is the reference.
- iOS: CocoaPods (`mobile_shield.podspec`) and SwiftPM (`ios/mobile_shield/Package.swift`) both use `ios/mobile_shield/Frameworks/MobileShieldCore.xcframework`. After re-syncing the framework, run `fvm flutter clean` and rebuild (CocoaPods: `pod install` in `ios/`). `consumers/flutter-app/build.sh ios-cocoapods|ios-spm` shows a full clean rebuild for each mode.
- Add-to-app (Flutter module in a native host): `packages/flutter/example_module` + `example_host`, and `consumers/flutter-module` + `consumers/android-host`; see [integration-flutter.md](integration-flutter.md#6-add-to-app-flutter-module-in-a-native-host). Both the host's `settings.gradle` and the module's generated `.android/build.gradle` need `mavenLocal()`. Flutter regenerates `.android/`, so `consumers/android-host/build.sh` re-inserts the line before `flutter build aar`.

## 5. Native Android host (no wrapper)

`implementation "io.mobileshield:core:<VERSION>"` with `mavenLocal()` first in `settings.gradle` `dependencyResolutionManagement` (centralized repositories). Reference: `consumers/android-host` (which also embeds the Flutter module from step 4).

## What to rebuild after a change

| You changed | Rebuild | Then in the consumer |
|---|---|---|
| RN `src/*.ts` | nothing | `file:`: Metro reload. Tarball: `npm pack` + reinstall |
| Flutter `lib/*.dart` | nothing | hot restart |
| RN/Flutter wrapper native code (`packages/*/android`, `packages/*/ios`) | nothing | rebuild the app (tarball: re-pack + reinstall first); iOS: `pod install` if files were added or removed |
| Android core (`core-android/`) | `./scripts/build-aar.sh` | rebuild the app (Maven Local is read fresh) |
| iOS core (`core-ios/`) | `./scripts/build-xcframework.sh && ./scripts/sync-binaries.sh` | `pod install` / `flutter clean`, rebuild; tarball: re-pack + reinstall |
| `VERSION` | all of the above, then `./scripts/check-versions.sh` | reinstall; the wrappers now pin the new core version |
| Contracts (enum values, error names, config keys) | change all four layers together (see `CLAUDE.md`) and rebuild both cores | full rebuild |

## Checking what the app actually loaded

`getSdkVersion()` returns the core's `VERSION`; it should match the checkout. The packaging-matrix scripts do this end to end: `consumers/rn-072/build.sh android|ios-default|ios-static`, `consumers/rn-086/build.sh android|ios`, `consumers/flutter-app/build.sh android|ios-cocoapods|ios-spm` and `consumers/android-host/build.sh` (Flutter module AAR + native host, fresh Gradle cache) build in release mode and run the 16 KB page-size check on Android; the iOS modes launch the app in a simulator and look for `sdkVersion=<VERSION>` in the log. They expect a macOS developer machine (`/usr/libexec/java_home`, `~/Library/Android/sdk`, `xcrun`).

## Before switching back to a published version

- Remove `mavenLocal()` from the consumer.
- Replace the `file:` / tarball dependency with `npm install --save-exact @whoistus/react-native-mobile-shield@<version>`, and the Flutter `path:` dependency with the git dependency pinned to a tag.
- Remove the `watchFolders` / `blockList` Metro entries if they were only there for the link.
