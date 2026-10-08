#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
IOS="$ROOT/core-ios"
BUILD="$IOS/build"
OUT="$BUILD/MobileShieldCore.xcframework"

rm -rf "$BUILD"
mkdir -p "$BUILD"

archive() {
  local dest="$1" name="$2"
  xcodebuild archive \
    -project "$IOS/MobileShieldCore.xcodeproj" \
    -scheme MobileShieldCore \
    -configuration Release \
    -destination "$dest" \
    -archivePath "$BUILD/$name.xcarchive" \
    -derivedDataPath "$BUILD/derived" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    MS_VERSION_STRING="$VERSION" \
    ARCHS="${3}" ONLY_ACTIVE_ARCH=NO \
    -quiet
}

archive "generic/platform=iOS" ios "arm64"
archive "generic/platform=iOS Simulator" ios-sim "arm64 x86_64"

ARGS=()
for name in ios ios-sim; do
  ARGS+=(-framework "$BUILD/$name.xcarchive/Products/Library/Frameworks/MobileShieldCore.framework")
  if [ -d "$BUILD/$name.xcarchive/dSYMs/MobileShieldCore.framework.dSYM" ]; then
    ARGS+=(-debug-symbols "$BUILD/$name.xcarchive/dSYMs/MobileShieldCore.framework.dSYM")
  fi
done

xcodebuild -create-xcframework "${ARGS[@]}" -output "$OUT"
echo "$OUT"
