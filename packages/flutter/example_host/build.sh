#!/usr/bin/env bash
# Flutter module -> release AAR repo -> native host resolving core with a fresh Gradle cache.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21 2>/dev/null || true)}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

cd "$HERE/../example_module"
flutter pub get
# The generated .android/ project has no mavenLocal(); the plugin needs it to resolve core locally.
# Real hosts use the GitHub Packages block from docs/consumer-setup.md instead.
grep -q mavenLocal .android/build.gradle || sed -i '' 's/^        google()$/        mavenLocal()\n        google()/' .android/build.gradle
flutter build aar --no-debug --no-profile --build-number 1.0

cd "$HERE"
GUH="$(mktemp -d)"
trap 'rm -rf "$GUH"' EXIT
./gradlew --gradle-user-home "$GUH" --no-daemon --no-build-cache --refresh-dependencies assembleRelease
"$ROOT/scripts/check-16kb.sh" app/build/outputs/apk/release/*.apk
