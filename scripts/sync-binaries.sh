#!/usr/bin/env bash
# Copy the XCFramework into both wrappers, stamp VERSION, verify identical content.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC="core-ios/build/MobileShieldCore.xcframework"
RN="packages/react-native"
FL="packages/flutter"
VERSION="$(tr -d '[:space:]' < VERSION)"

[ -d "$SRC" ] || { echo "ERROR: $SRC not found. Run scripts/build-xcframework.sh first." >&2; exit 1; }
[ -n "$VERSION" ] || { echo "ERROR: VERSION is empty" >&2; exit 1; }

# SwiftPM rejects binaryTarget paths outside the package root, so Flutter's copy
# lives inside ios/mobile_shield (the SwiftPM package); the podspec points there too.
RN_FW="$RN/ios/Frameworks/MobileShieldCore.xcframework"
FL_FW="$FL/ios/mobile_shield/Frameworks/MobileShieldCore.xcframework"
for dst in "$RN_FW" "$FL_FW"; do
  mkdir -p "$(dirname "$dst")"
  rm -rf "$dst"
  cp -R "$SRC" "$dst"
done

# stamp <file> <perl-substitution>; fails if the file is missing or nothing changed shape
stamp() {
  local file="$1" expr="$2"
  [ -f "$file" ] || { echo "ERROR: missing $file" >&2; exit 1; }
  V="$VERSION" perl -0pi -e "$expr" "$file"
  grep -qF "$VERSION" "$file" || { echo "ERROR: version stamp did not apply to $file" >&2; exit 1; }
}

stamp "$RN/package.json"                  's/("version"\s*:\s*")[^"]*(")/$1$ENV{V}$2/'
stamp "$RN/MobileShield.podspec"          's/(s\.version\s*=\s*")[^"]*(")/$1$ENV{V}$2/'
stamp "$RN/android/build.gradle"          's/(io\.mobileshield:core:)[^"\x27]+/$1$ENV{V}/'
stamp "$FL/pubspec.yaml"                  's/^(version:\s*).*$/$1$ENV{V}/m'
stamp "$FL/ios/mobile_shield.podspec"     's/(s\.version\s*=\s*\x27)[^\x27]*(\x27)/$1$ENV{V}$2/'
stamp "$FL/android/build.gradle"          's/(io\.mobileshield:core:)[^"\x27]+/$1$ENV{V}/; s/^(version\s+\x27)[^\x27]*(\x27)/$1$ENV{V}$2/m'
stamp "$FL/ios/mobile_shield/Package.swift" 's/(let mobileShieldVersion = ")[^"]*(")/$1$ENV{V}$2/'

# Keep the iOS project default in step with VERSION so a plain `xcodebuild test` matches.
stamp "core-ios/project.yml"              's/(MS_VERSION_STRING:\s*")[^"]*(")/$1$ENV{V}$2/'
stamp "core-ios/MobileShieldCore.xcodeproj/project.pbxproj" 's/(MS_VERSION_STRING = )[^;]*;/$1$ENV{V};/g'

# Every package ships the license and third-party notices.
for pkg in "$RN" "$FL"; do
  cp LICENSE THIRD_PARTY_NOTICES.md "$pkg/"
done

# Hash of file paths + contents, independent of timestamps.
tree_hash() {
  (cd "$1" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | cut -d' ' -f1)
}
H_SRC="$(tree_hash "$SRC")"
H_RN="$(tree_hash "$RN_FW")"
H_FL="$(tree_hash "$FL_FW")"

if [ "$H_RN" != "$H_FL" ] || [ "$H_RN" != "$H_SRC" ]; then
  echo "ERROR: xcframework hash mismatch (src=$H_SRC rn=$H_RN flutter=$H_FL)" >&2
  exit 1
fi
echo "sync-binaries: version=$VERSION xcframework sha256=$H_RN (identical in both wrappers)"
