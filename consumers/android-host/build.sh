#!/usr/bin/env bash
# Flutter module -> release AAR in local repo -> native host consumes it.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# Local dev pins Flutter 3.27.4 via fvm; CI provides flutter on PATH.
[ -d "$HOME/fvm/versions/3.27.4/bin" ] && export PATH="$HOME/fvm/versions/3.27.4/bin:$PATH"
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21 2>/dev/null || true)}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

cd "$HERE/../flutter-module"
flutter pub get
# Generated .android/ has no mavenLocal(); the plugin needs it to resolve core 0.1.0 locally
# (real consumers use the GitHub Packages block from docs/consumer-setup.md instead).
grep -q mavenLocal .android/build.gradle || sed -i '' 's/^        google()$/        mavenLocal()\n        google()/' .android/build.gradle
flutter build aar --no-debug --no-profile --build-number 1.0

cd "$HERE"
echo "--- FAIL_ON_PROJECT_REPOS check"
grep -n 'FAIL_ON_PROJECT_REPOS' settings.gradle
# Fresh gradle user home: host must not rely on the producer's cache.
GUH="$(mktemp -d)"
trap 'rm -rf "$GUH"' EXIT
./gradlew --gradle-user-home "$GUH" --no-daemon assembleRelease

APK=app/build/outputs/apk/release/app-release-unsigned.apk
[ -f "$APK" ] || APK="$(ls app/build/outputs/apk/release/*.apk | head -1)"
"$ROOT/scripts/check-16kb.sh" "$APK"
echo "PASS android-host"
