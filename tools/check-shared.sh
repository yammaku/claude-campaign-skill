#!/bin/sh
# Check the contract between the campaign and campaign-native skills: the same Campaign file layout
# (references/campaign-file.md) and the same templates from campaign-init.sh and chief.sh.
# Usage: sh tools/check-shared.sh   (from the repo root)
set -eu

fail=0
if ! cmp -s campaign/references/campaign-file.md campaign-native/references/campaign-file.md; then
  echo "campaign-file.md differs between the two skills:" >&2
  diff -u campaign/references/campaign-file.md campaign-native/references/campaign-file.md >&2 || true
  fail=1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/a" "$tmp/b"
git -C "$tmp/a" init -q
git -C "$tmp/b" init -q
sh campaign/scripts/campaign-init.sh probe "$tmp/a" >/dev/null 2>&1
sh campaign-native/scripts/chief.sh probe "$tmp/b" >/dev/null 2>&1
for d in a b; do
  # Drop the lines that differ by design: start time and repo path.
  sed -i.bak -e '/^- Started: /d' -e '/^- Repo: /d' "$tmp/$d"/.campaigns/*-probe/campaign.md
  rm "$tmp/$d"/.campaigns/*-probe/campaign.md.bak
done
if ! diff -ru "$tmp/a"/.campaigns/*-probe "$tmp/b"/.campaigns/*-probe >&2; then
  echo "campaign-init.sh and chief.sh create different Campaign files" >&2
  fail=1
fi
for d in a b; do
  grep -qx '.campaigns/' "$tmp/$d/.git/info/exclude" || { echo "$d: .campaigns/ not in .git/info/exclude" >&2; fail=1; }
done

[ "$fail" = 0 ] && echo "shared contract ok"
exit "$fail"
