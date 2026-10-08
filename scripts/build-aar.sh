#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$ROOT/core-android"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

cd "$CORE"
./gradlew --no-daemon :core:testReleaseUnitTest :core:assembleRelease :core:publishToMavenLocal "$@"

SRC="$CORE/core/build/outputs/aar/core-release.aar"
OUT="$CORE/build/outputs/core-$VERSION.aar"
mkdir -p "$(dirname "$OUT")"
cp "$SRC" "$OUT"

echo "AAR: $OUT"
echo "Unstripped libs (for symbolication):"
find "$CORE/core/build/intermediates/cxx" -path '*obj/*' -name 'libmobileshield.so' 2>/dev/null | sort || true
