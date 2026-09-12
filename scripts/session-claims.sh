#!/usr/bin/env bash
# Print in-flight issues and their claimed branch when a session starts
# (#1703): a hand-written brief describes the picture as it was when
# drafted, and by the time the opener is pasted it has usually moved.
# Cached for a few minutes so a burst of session starts doesn't hit the API
# each time; silent (no output, exit 0) whenever gh, jq or the network
# aren't available, since a SessionStart hook failing loud is worse than one
# saying nothing.

set -euo pipefail

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/claim-branch.sh
source "$lib_dir/lib/claim-branch.sh"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || exit 0
cd "$repo_root" || exit 0

repo="jonyardley/intrada"
cache_file="$common_dir/intrada-session-claims-cache.txt"
cache_ttl_seconds="${INTRADA_CLAIMS_CACHE_TTL:-180}"
case "$cache_ttl_seconds" in
  '' | *[!0-9]*) cache_ttl_seconds=180 ;;
esac

command -v gh >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

now="$(date +%s)"
if [ -f "$cache_file" ]; then
  mtime="$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)"
  if [ $((now - mtime)) -lt "$cache_ttl_seconds" ]; then
    cat "$cache_file"
    exit 0
  fi
fi

claimed="$(gh issue list --repo "$repo" --label in-flight --state open --limit 50 \
  --json number,title 2>/dev/null)" || exit 0
open_prs="$(gh pr list --repo "$repo" --state open --limit 50 \
  --json number,closingIssuesReferences 2>/dev/null)" || exit 0

lines=""
while IFS= read -r row; do
  [ -z "$row" ] && continue
  number="$(jq -r '.number' <<<"$row")"
  title="$(jq -r '.title' <<<"$row")"
  claim_body="$(gh issue view "$number" --repo "$repo" --json comments -q \
    '[.comments[] | select(.body | test("^Claimed"; "i"))] | last | .body // empty' 2>/dev/null)" || claim_body=""
  branch="$(claim_branch_from_body "$claim_body")"
  [ -z "$branch" ] && branch="unknown"
  pr="$(jq -r --argjson n "$number" \
    '[.[] | select(.closingIssuesReferences[]?.number == $n)][0].number // empty' <<<"$open_prs")"
  line="- #$number: $title
    branch $branch"
  [ -n "$pr" ] && line="$line, PR #$pr"
  lines="$lines$line
"
done < <(jq -c '.[]' <<<"$claimed")

if [ -z "$lines" ]; then
  output="No issues claimed in-flight right now."
else
  output="In flight right now (from GitHub); stop if yours is claimed under another branch:
$lines"
fi

mkdir -p "$(dirname "$cache_file")"
tmp_cache="$(mktemp "${cache_file}.XXXXXX")"
printf '%s\n' "$output" >"$tmp_cache"
mv "$tmp_cache" "$cache_file"
printf '%s\n' "$output"
