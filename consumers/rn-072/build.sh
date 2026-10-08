#!/usr/bin/env bash
# usage: build.sh [android|ios-default|ios-static]
set -euo pipefail

MODE="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
APP=MsRn072
BUNDLE_ID=org.reactjs.native.example.MsRn072
EXPECT="sdkVersion=$(tr -d '[:space:]' < "$ROOT/VERSION")"

[ -d "$HERE/node_modules" ] || (cd "$HERE" && npm install --no-audit --no-fund --legacy-peer-deps)

case "$MODE" in
  android)
    export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    # RN 0.72 / Gradle 8.0 cannot run on JDK 21; needs 17.
    if [ -z "${JAVA_HOME:-}" ] || ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -q '"17\.'; then
      J17="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
      [ -n "$J17" ] || J17="$(ls -d "$HOME"/Library/Java/JavaVirtualMachines/temurin-17*/Contents/Home 2>/dev/null | head -1)"
      [ -n "$J17" ] || { echo "JDK 17 required for RN 0.72" >&2; exit 1; }
      export JAVA_HOME="$J17"
    fi
    (cd "$HERE/android" && ./gradlew assembleRelease)
    APK="$HERE/android/app/build/outputs/apk/release/app-release.apk"
    [ -f "$APK" ] || { echo "APK missing: $APK" >&2; exit 1; }
    # unzip may prompt on case-colliding res names (APFS); answer "None"
    # Gate the SDK's own libs; React Native's libs are listed as INFO (RN 0.72 is not 16KB-clean, out of scope).
    "$ROOT/scripts/check-16kb.sh" --only libmobileshield "$APK"
    ;;
  ios-default|ios-static)
    export NO_FLIPPER="${NO_FLIPPER:-}"
    if [ "$MODE" = ios-static ]; then export MS_LINKAGE=static NO_FLIPPER=1; else unset MS_LINKAGE; fi
    (cd "$HERE/ios" && pod install)
    DD="$HERE/ios/build/$MODE"
    xcodebuild -workspace "$HERE/ios/$APP.xcworkspace" -scheme "$APP" -configuration Release \
      -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$DD" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO EXCLUDED_ARCHS=x86_64 build
    APPDIR="$DD/Build/Products/Release-iphonesimulator/$APP.app"
    [ -d "$APPDIR" ] || { echo "app missing: $APPDIR" >&2; exit 1; }

    UDID="$(xcrun simctl list devices booted | grep -Eo '[0-9A-F-]{36}' | head -1 || true)"
    if [ -z "$UDID" ]; then
      UDID="$(xcrun simctl list devices available | grep -E 'iPhone [0-9]+' | grep -Eo '[0-9A-F-]{36}' | head -1 || true)"
      [ -n "$UDID" ] || { echo "no available iPhone simulator" >&2; exit 1; }
      xcrun simctl boot "$UDID"
      xcrun simctl bootstatus "$UDID" -b >/dev/null
    fi
    xcrun simctl install "$UDID" "$APPDIR"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    LOG="$(mktemp)"
    xcrun simctl spawn "$UDID" log stream --style compact --predicate "process == \"$APP\"" >"$LOG" 2>&1 &
    LP=$!
    sleep 3
    xcrun simctl launch "$UDID" "$BUNDLE_ID"
    sleep 8
    kill "$LP" 2>/dev/null || true
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    grep -m1 "$EXPECT" "$LOG" || { echo "FAIL: '$EXPECT' not found in app log" >&2; exit 1; }
    ;;
  *)
    echo "usage: $0 [android|ios-default|ios-static]" >&2; exit 64 ;;
esac
