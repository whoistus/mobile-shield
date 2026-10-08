#!/usr/bin/env bash
# usage: build.sh [android|ios]   (RN 0.86, New Architecture on)
set -euo pipefail

MODE="${1:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
APP=MsRn086
BUNDLE_ID=org.reactjs.native.example.MsRn086
EXPECT="sdkVersion=$(tr -d '[:space:]' < "$ROOT/VERSION")"

[ -d "$HERE/node_modules" ] || (cd "$HERE" && npm install --no-audit --no-fund)

case "$MODE" in
  android)
    export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    (cd "$HERE/android" && ./gradlew assembleRelease)
    APK="$HERE/android/app/build/outputs/apk/release/app-release.apk"
    [ -f "$APK" ] || { echo "APK missing: $APK" >&2; exit 1; }
    # RN 0.86 ships 16KB-aligned libs: gate every packaged .so.
    "$ROOT/scripts/check-16kb.sh" "$APK"
    ;;
  ios)
    (cd "$HERE/ios" && pod install)
    DD="$HERE/ios/build"
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
    echo "usage: $0 [android|ios]" >&2; exit 64 ;;
esac
