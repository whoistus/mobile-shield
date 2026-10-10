#!/usr/bin/env bash
# Fail unless every stamped version equals VERSION (and the tag, when given).
# Usage: scripts/check-versions.sh [vX.Y.Z[-rc.N]]
# Mirrors the stamps in sync-binaries.sh; used by it and by release.yml.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXPECTED="$(tr -d '[:space:]' < VERSION)"
TAG="${1:-}"
fail=0
complain() { echo "MISMATCH: $*" >&2; fail=1; }

SEMVER='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'
[[ "$EXPECTED" =~ $SEMVER ]] || { echo "VERSION '$EXPECTED' is not semver" >&2; exit 1; }

if [ -n "$TAG" ] && [ "${TAG#v}" != "$EXPECTED" ]; then
  complain "tag $TAG != VERSION $EXPECTED"
fi

# check <file> <label> <perl regex with one capture group>; every match must equal VERSION.
check() {
  local file="$1" label="$2" expr="$3" found value n=0
  if [ ! -f "$file" ]; then complain "$file missing"; return; fi
  found="$(E="$expr" perl -0ne 'my $r = $ENV{E}; while (/$r/mg) { print "$1\n" }' "$file")"
  while IFS= read -r value; do
    [ -n "$value" ] || continue
    n=$((n + 1))
    [ "$value" = "$EXPECTED" ] || complain "$file ($label) = $value, VERSION = $EXPECTED"
  done <<< "$found"
  [ "$n" -gt 0 ] || complain "$file ($label): no version found"
}

RN=packages/react-native
FL=packages/flutter
check "$RN/package.json"                    "package version"   '^\s*"version"\s*:\s*"([^"]*)"'
check "$RN/MobileShield.podspec"            "podspec version"   's\.version\s*=\s*"([^"]*)"'
check "$RN/android/build.gradle"            "core dependency"   'io\.mobileshield:core:([^"\x27]+)'
check "$FL/pubspec.yaml"                    "pubspec version"   '^version:\s*(\S+)'
check "$FL/ios/mobile_shield.podspec"       "podspec version"   's\.version\s*=\s*\x27([^\x27]*)\x27'
check "$FL/android/build.gradle"            "core dependency"   'io\.mobileshield:core:([^"\x27]+)'
check "$FL/android/build.gradle"            "gradle version"    '^version\s+\x27([^\x27]*)\x27'
check "$FL/ios/mobile_shield/Package.swift" "Package.swift"     'let mobileShieldVersion = "([^"]*)"'
check core-ios/project.yml                  "MS_VERSION_STRING" 'MS_VERSION_STRING:\s*"([^"]*)"'
check core-ios/MobileShieldCore.xcodeproj/project.pbxproj "MS_VERSION_STRING" 'MS_VERSION_STRING = ([^;]*);'

if [ "$fail" -ne 0 ]; then
  echo "check-versions: FAILED (expected $EXPECTED${TAG:+, tag $TAG})" >&2
  exit 1
fi
echo "check-versions: OK $EXPECTED${TAG:+ (tag $TAG)}"
