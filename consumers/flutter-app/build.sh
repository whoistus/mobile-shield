#!/usr/bin/env bash
# usage: build.sh [android|ios-cocoapods|ios-spm]
set -euo pipefail
MODE="${1:-android}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# Local dev pins Flutter 3.27.4 via fvm; CI provides flutter on PATH.
[ -d "$HOME/fvm/versions/3.27.4/bin" ] && export PATH="$HOME/fvm/versions/3.27.4/bin:$PATH"
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21 2>/dev/null || true)}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
cd "$HERE"

APP_ID=io.mobileshield.consumer.flutterApp
EXPECT="sdkVersion=$(tr -d '[:space:]' < "$ROOT/VERSION")"

ios_run() {
  local spm="$1"
  # flutter config persists in ~/.config/flutter/settings; snapshot/restore that file exactly.
  SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/flutter/settings"
  SNAP="$(mktemp)"; HAD=0
  if [ -f "$SETTINGS" ]; then cp "$SETTINGS" "$SNAP"; HAD=1; fi
  restore() {
    if [ "$HAD" = 1 ]; then cp "$SNAP" "$SETTINGS"; else rm -f "$SETTINGS"; fi
  }
  trap restore EXIT
  if [ "$spm" = 1 ]; then flutter config --enable-swift-package-manager; else flutter config --no-enable-swift-package-manager; fi

  flutter clean >/dev/null
  rm -rf ios/Pods ios/Podfile.lock ios/Flutter/ephemeral ios/.symlinks
  flutter pub get
  flutter build ios --simulator --debug

  local udid
  udid="$(xcrun simctl list devices booted | grep -Eo '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | head -1 || true)"
  if [ -z "$udid" ]; then
    udid="$(xcrun simctl list devices available | grep -E 'iPhone' | grep -Eo '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | head -1)"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b >/dev/null
  fi
  xcrun simctl install "$udid" build/ios/iphonesimulator/Runner.app
  xcrun simctl terminate "$udid" "$APP_ID" 2>/dev/null || true
  local log; log="$(mktemp)"
  xcrun simctl spawn "$udid" log stream --style compact --predicate 'eventMessage CONTAINS "sdkVersion="' >"$log" 2>&1 &
  local pid=$!
  sleep 2
  xcrun simctl launch "$udid" "$APP_ID"
  # A freshly booted CI simulator can take well over 30 s to start a debug Flutter app.
  for _ in $(seq 1 90); do
    grep -q "flutter: $EXPECT" "$log" && break
    sleep 1
  done
  kill "$pid" 2>/dev/null || true
  # The live stream can attach late and miss the line; the persisted log still has it.
  grep -q "$EXPECT" "$log" || xcrun simctl spawn "$udid" log show --last 5m --style compact \
    --predicate 'eventMessage CONTAINS "sdkVersion="' >>"$log" 2>&1 || true
  xcrun simctl terminate "$udid" "$APP_ID" 2>/dev/null || true
  if grep -h 'sdkVersion=' "$log"; then
    grep -q "$EXPECT" "$log" && echo "PASS ios (spm=$spm)" && return 0
  fi
  echo "FAIL ios (spm=$spm): $EXPECT not in log"; cat "$log"; return 1
}

case "$MODE" in
  android)
    flutter pub get
    flutter build apk --release
    "$ROOT/scripts/check-16kb.sh" build/app/outputs/flutter-apk/app-release.apk
    echo "PASS android"
    ;;
  ios-cocoapods) ios_run 0 ;;
  ios-spm) ios_run 1 ;;
  *) echo "usage: $0 [android|ios-cocoapods|ios-spm]" >&2; exit 64 ;;
esac
