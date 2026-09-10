#!/usr/bin/env bash
# raw.githubusercontent.com URLs pin a commit SHA rather than a branch name,
# so the images here still resolve after the branch moves or is deleted (#1631).
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

# Encode each path segment so a space, bracket or non-ASCII character in a
# snapshot filename survives as a working link; the slashes between segments
# stay literal. `read -ra` splits on IFS without word-splitting or pathname
# expansion, unlike an unquoted `for segment in $path`, which would glob a
# filename that happens to contain [ ] * or ? against files in the repo.
urlencode_path() {
  local path="$1" segment joined="" segs
  IFS='/' read -ra segs <<<"$path"
  for segment in "${segs[@]}"; do
    segment="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$segment")"
    joined="${joined:+$joined/}$segment"
  done
  printf '%s' "$joined"
}

raw_url() {
  local sha="$1" path="$2"
  printf '%s' "https://raw.githubusercontent.com/$repo/$sha/$(urlencode_path "$path")"
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

# -z is the load-bearing flag: it disables git's default quoting of a
# non-ASCII or otherwise "unusual" path (octal escapes inside literal
# double-quotes), which would otherwise survive uninterpreted into the URL. A
# rename or copy prints three NUL-terminated fields (status, old path, new
# path) instead of two, so the entries are walked by hand rather than read
# line by line. `read -d ''` rather than `mapfile -d`, which macOS's shipped
# bash (3.2) does not have.
entries=()
while IFS= read -r -d '' field; do
  entries+=("$field")
done < <(git diff -z --name-status -M "$base_sha" "$head_sha" -- "$snap_dir")

if [ "${#entries[@]}" -eq 0 ]; then
  echo "This branch changed no snapshot references."
  exit 0
fi

i=0
while [ "$i" -lt "${#entries[@]}" ]; do
  status="${entries[$i]}"
  case "$status" in
    A*)
      path1="${entries[$((i + 1))]}"
      i=$((i + 2))
      emit_pair "$path1" "_(new reference)_" "![after]($(raw_url "$head_sha" "$path1"))"
      ;;
    D*)
      path1="${entries[$((i + 1))]}"
      i=$((i + 2))
      emit_pair "$path1" "![before]($(raw_url "$base_sha" "$path1"))" "_(removed)_"
      ;;
    R* | C*)
      path1="${entries[$((i + 1))]}"
      path2="${entries[$((i + 2))]}"
      i=$((i + 3))
      emit_pair "$path1 -> $path2" \
        "![before]($(raw_url "$base_sha" "$path1"))" \
        "![after]($(raw_url "$head_sha" "$path2"))"
      ;;
    *)
      path1="${entries[$((i + 1))]}"
      i=$((i + 2))
      emit_pair "$path1" \
        "![before]($(raw_url "$base_sha" "$path1"))" \
        "![after]($(raw_url "$head_sha" "$path1"))"
      ;;
  esac
done
