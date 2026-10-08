#!/usr/bin/env bash
# Repo hygiene gate over tracked + untracked-not-ignored files (what would be committed).
# Patterns use bracket tricks so this file does not match itself.
set -u
cd "$(dirname "$0")/.."

fail=0
NAMES='tm[d]s\|micro[p]ay\|thai[m]icro'

files() { git ls-files -co --exclude-standard -z; }

names=$(files | grep -zv -e '^THIRD_PARTY_NOTICES.md$' -e '/THIRD_PARTY_NOTICES.md$' \
  | xargs -0 grep -Iil "$NAMES" 2>/dev/null || true)
# Binaries too (vendored xcframeworks, AARs): -a treats them as text.
bins=$(files | grep -z -e '\.xcframework/' -e '\.aar$' -e '\.so$' \
  | xargs -0 grep -ail "$NAMES" 2>/dev/null || true)
names="$(printf '%s\n%s' "$names" "$bins" | sed '/^$/d' | sort -u)"
if [ -n "$names" ]; then
  echo "FORBIDDEN: internal product/company names found in:" >&2
  echo "$names" >&2
  fail=1
fi

gpl=$(files | grep -z -e '^core-android/' -e '^core-ios/' \
  | xargs -0 grep -Il 'LSPose[d]\|GNU General Publi[c]' 2>/dev/null || true)
if [ -n "$gpl" ]; then
  echo "FORBIDDEN: GPL/LSPosed markers found in:" >&2
  echo "$gpl" >&2
  fail=1
fi

[ "$fail" -eq 0 ] && echo "check-forbidden-strings: OK"
exit "$fail"
