#!/usr/bin/env bash
# Print the before/after markdown for every snapshot reference this branch
# changed, ready to paste under "What it looks like" in a PR body (#1631).
# Images are raw.githubusercontent.com URLs pinned to a commit SHA, never a
# branch name, so they still resolve after the branch moves or is deleted.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

repo="jonyardley/intrada"
snap_dir="ios/IntradaTests/__Snapshots__"
bt='`'

# Overridable for the self-test in scripts/tests/pr-visuals-test.sh, which
# points these at two commits in a throwaway repo rather than a real remote.
base_ref="${PR_VISUALS_BASE:-origin/main}"
head_ref="${PR_VISUALS_HEAD:-HEAD}"

if ! git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
  echo "cannot resolve $base_ref (fetch origin first)" >&2
  exit 1
fi
if ! git rev-parse --verify "$head_ref" >/dev/null 2>&1; then
  echo "cannot resolve $head_ref" >&2
  exit 1
fi

base_sha="$(git merge-base "$base_ref" "$head_ref")"
head_sha="$(git rev-parse "$head_ref")"

# Encode each path segment so a space or bracket in a snapshot filename
# survives as a working link; the slashes between segments stay literal.
urlencode_path() {
  local path="$1" segment joined=""
  local IFS='/'
  for segment in $path; do
    segment="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$segment")"
    if [ -z "$joined" ]; then
      joined="$segment"
    else
      joined="$joined/$segment"
    fi
  done
  echo "$joined"
}

raw_url() {
  local sha="$1" path="$2"
  echo "https://raw.githubusercontent.com/$repo/$sha/$(urlencode_path "$path")"
}

emit_pair() {
  local heading="$1" before_cell="$2" after_cell="$3"
  cat <<MD

### ${bt}${heading}${bt}

| Before | After |
| --- | --- |
| $before_cell | $after_cell |
MD
}

diff_output="$(git diff --name-status -M "$base_sha" "$head_sha" -- "$snap_dir")"

if [ -z "$diff_output" ]; then
  echo "This branch changed no snapshot references."
  exit 0
fi

while IFS=$'\t' read -r status path1 path2; do
  [ -n "$status" ] || continue
  case "$status" in
    A*)
      emit_pair "$path1" "_(new reference)_" "![after]($(raw_url "$head_sha" "$path1"))"
      ;;
    D*)
      emit_pair "$path1" "![before]($(raw_url "$base_sha" "$path1"))" "_(removed)_"
      ;;
    R*|C*)
      emit_pair "$path1 -> $path2" \
        "![before]($(raw_url "$base_sha" "$path1"))" \
        "![after]($(raw_url "$head_sha" "$path2"))"
      ;;
    *)
      emit_pair "$path1" \
        "![before]($(raw_url "$base_sha" "$path1"))" \
        "![after]($(raw_url "$head_sha" "$path1"))"
      ;;
  esac
done <<EOF
$diff_output
EOF
