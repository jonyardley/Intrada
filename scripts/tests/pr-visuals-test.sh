#!/usr/bin/env bash
# Self-test for scripts/pr-visuals.sh. Builds a throwaway git repo with a
# modified, an added and a deleted snapshot reference, then asserts the
# recipe reports each shape correctly, plus the no-change case, without
# touching the network.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/scripts/pr-visuals.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
snap="ios/IntradaTests/__Snapshots__/ScreenSnapshotTests"
mkdir -p "$repo/$snap"
cd "$repo"
git init -q
git config user.email test@example.com
git config user.name test

printf 'base-a' >"$snap/testKept.1.png"
printf 'base-b' >"$snap/testRemoved.1.png"
git add -A
git commit -q -m base
base_sha="$(git rev-parse HEAD)"

printf 'head-a' >"$snap/testKept.1.png"
git rm -q "$snap/testRemoved.1.png"
printf 'new' >"$snap/test With Space.1.png"
git add -A
git commit -q -m head
head_sha="$(git rev-parse HEAD)"

pass=0
fail=0

check() {
  local haystack="$1" desc="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $desc (expected to find: $needle)" >&2
  fi
}

changed="$(PR_VISUALS_BASE="$base_sha" PR_VISUALS_HEAD="$head_sha" "$script")"

check "$changed" "modified reference links the before at the base sha" \
  "$base_sha/$snap/testKept.1.png"
check "$changed" "modified reference links the after at the head sha" \
  "$head_sha/$snap/testKept.1.png"
check "$changed" "added reference has no before" "_(new reference)_"
check "$changed" "added reference links the after at the head sha" \
  "$head_sha/$snap/test%20With%20Space.1.png"
check "$changed" "deleted reference has no after" "_(removed)_"
check "$changed" "deleted reference links the before at the base sha" \
  "$base_sha/$snap/testRemoved.1.png"
check "$changed" "a space in the filename is percent-encoded" \
  "test%20With%20Space.1.png"

unchanged="$(PR_VISUALS_BASE="$head_sha" PR_VISUALS_HEAD="$head_sha" "$script")"
check "$unchanged" "no changes reads as one line, not an empty table" \
  "This branch changed no snapshot references."

echo "pr-visuals-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
