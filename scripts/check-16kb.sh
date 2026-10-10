#!/usr/bin/env bash
# Fails if any packaged 64-bit .so has a LOAD segment alignment below 0x4000 (16 KB).
# 16 KB page-size devices only run 64-bit code, so 32-bit ABIs (armeabi-v7a, x86) are
# listed as INFO-* and never fail the run (e.g. RootBeer's 32-bit libtoolChecker is 4 KB).
set -euo pipefail

# usage: check-16kb.sh [--only <regex>] <apk|aab|aar>
#   --only: gate only libs whose path matches <regex> (e.g. libmobileshield);
#           other libs are still listed as INFO-OK / INFO-FAIL but never fail the run.
ONLY=""
if [ "${1:-}" = "--only" ]; then ONLY="${2:-}"; shift 2 || true; fi
[ $# -eq 1 ] || { echo "usage: $0 [--only <regex>] <apk|aab|aar>" >&2; exit 64; }
ARCHIVE="$1"
[ -f "$ARCHIVE" ] || { echo "not found: $ARCHIVE" >&2; exit 64; }

ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
READELF="$(ls "$ANDROID_HOME"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-readelf 2>/dev/null | sort | tail -1 || true)"
[ -n "$READELF" ] || { echo "llvm-readelf not found under $ANDROID_HOME/ndk" >&2; exit 64; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Extract only native libs: avoids case-collision prompts on APFS and is faster.
unzip -qo "$ARCHIVE" '*.so' -d "$TMP" 2>/dev/null || true

case "$ARCHIVE" in
  *.aar) PATTERNS=("jni/*/*.so") ;;
  *.aab) PATTERNS=("base/lib/*/*.so" "*/lib/*/*.so") ;;
  *)     PATTERNS=("lib/*/*.so") ;;
esac

FILES="$(cd "$TMP" && for p in "${PATTERNS[@]}"; do compgen -G "$p" || true; done | sort -u)"
if [ -z "$FILES" ]; then
  echo "no .so found in $ARCHIVE" >&2
  exit 2
fi

FAIL=0
GATED=0
printf '%-45s %-10s %s\n' FILE MIN_ALIGN STATUS
while IFS= read -r f; do
  abi="$(basename "$(dirname "$f")")"
  info=0
  if [ -n "$ONLY" ] && ! [[ "$f" =~ $ONLY ]]; then info=1; fi
  case "$abi" in arm64-v8a|x86_64) ;; *) info=1 ;; esac
  MIN=""
  while read -r a; do
    v=$((a))
    if [ -z "$MIN" ] || [ "$v" -lt "$MIN" ]; then MIN=$v; fi
  done < <("$READELF" -lW "$TMP/$f" | awk '$1=="LOAD" {print $NF}')
  if [ -z "$MIN" ]; then
    if [ "$info" -eq 1 ]; then
      printf '%-45s %-10s %s\n' "$f" "-" "INFO-NO-LOAD"; continue
    fi
    printf '%-45s %-10s %s\n' "$f" "-" "NO-LOAD"; FAIL=1; GATED=1; continue
  fi
  if [ "$info" -eq 1 ]; then
    if [ "$MIN" -ge 16384 ]; then st=INFO-OK; else st=INFO-FAIL; fi
  elif [ "$MIN" -ge 16384 ]; then st=OK; GATED=1; else st=FAIL; FAIL=1; GATED=1; fi
  printf '%-45s 0x%-8x %s\n' "$f" "$MIN" "$st"
done <<< "$FILES"

if [ -n "$ONLY" ] && [ "$GATED" -eq 0 ]; then echo "no lib matched --only '$ONLY'" >&2; exit 2; fi
[ "$FAIL" -eq 0 ] && echo "16KB alignment: PASS" || { echo "16KB alignment: FAIL" >&2; exit 1; }
