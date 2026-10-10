#!/usr/bin/env bash
# Builds and runs the native policy/watchdog/integrity googletest suite with the host toolchain (no device needed).
# decision_vectors.inc is committed; regenerate it with scripts/fixtures/gen-config-vectors.py when vectors change.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${MS_NATIVE_HOST_BUILD:-$ROOT/build/native-host}"

# Fall back to the CMake + Ninja bundled with the Android SDK when they are not on PATH.
if ! command -v cmake >/dev/null || ! command -v ninja >/dev/null; then
  SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
  SDK_CMAKE="$(ls -d "$SDK"/cmake/*/bin 2>/dev/null | sort -V | tail -1 || true)"
  [ -n "$SDK_CMAKE" ] || { echo "ERROR: cmake/ninja not found on PATH or in $SDK/cmake" >&2; exit 1; }
  export PATH="$SDK_CMAKE:$PATH"
fi

cmake -S "$ROOT/core-android/core/src/test/cpp" -B "$OUT" -G Ninja
cmake --build "$OUT"
ctest --test-dir "$OUT" --output-on-failure
