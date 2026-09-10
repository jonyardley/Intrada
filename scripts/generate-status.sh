#!/usr/bin/env bash
# Print what is in flight, read from GitHub. The issues are the source of truth
# (CLAUDE.md), so this was always derivable; it used to be copied by hand into
# docs/status.md, which every concurrent branch then collided on. Nothing here
# writes a tracked file, which is the whole point.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

repo="jonyardley/intrada"
open_limit=50
claimed_limit=50
landed_limit=15

for tool in gh jq; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "❌ $tool is required" >&2
    exit 1
  }
done

open_prs=$(gh pr list --repo "$repo" --state open --limit "$open_limit" \
  --json number,title,isDraft,updatedAt,headRefName,closingIssuesReferences)
# --state merged sorts by creation, so a long-lived branch merged today can
# fall outside a window that newer-but-earlier-merged PRs stay in. Over-fetch
# and sort on mergedAt instead.
merged_prs=$(gh pr list --repo "$repo" --state merged --limit $((landed_limit * 6)) \
  --json number,title,mergedAt)
claimed=$(gh issue list --repo "$repo" --label in-flight --state open \
  --limit "$claimed_limit" --json number,title,updatedAt)

# The cut is gated on the milestone's headline, not on a date (docs/roadmap.md),
# so "is a release due" is only answerable next to the burn.
#
# Each read reports its own failure. An outage that printed an empty section
# would read as "no release in flight", which is the silent-wrong this script
# exists to remove, and swallowing the tags call took the whole script down
# with it under `set -e`.
milestones_error=""
if ! milestones=$(gh api "repos/$repo/milestones?state=open" 2>&1); then
  milestones_error=$(printf '%s' "$milestones" | head -1)
  milestones='[]'
fi

last_tag=""
tags_error=""
if tags=$(gh api "repos/$repo/tags?per_page=100" --jq '.[].name' 2>&1); then
  last_tag=$(printf '%s\n' "$tags" |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 || true)
else
  tags_error=$(printf '%s' "$tags" | head -1)
fi

# Interpolated into a line the reader trusts, so anything but a count is
# dropped rather than printed.
ahead=""
if [ -n "$last_tag" ]; then
  ahead=$(gh api "repos/$repo/compare/$last_tag...main" --jq '.ahead_by' 2>/dev/null || echo "")
  case "$ahead" in
    "" | *[!0-9]*) ahead="" ;;
  esac
fi

# `capture` emits nothing rather than null when it does not match, which would
# drop the whole row, so it is defaulted before the field is read.
issue_of='(.closingIssuesReferences[0].number
  // ((.title | capture("#(?<n>[0-9]+)\\)\\s*$") // null)
      | if . then (.n | tonumber) else null end))'

pr_lines=$(printf '%s' "$open_prs" | jq -r "
  sort_by(.updatedAt) | reverse | .[] |
  $issue_of as \$issue |
  \"- #\(.number) — \(.title)\"
  + (if .isDraft then \" (draft)\" else \"\" end)
  + (if \$issue then \" — issue #\(\$issue)\" else \"\" end)
  + \"\n    \(.headRefName), last touched \(.updatedAt | split(\"T\")[0])\"
")

claimed_lines=$(printf '%s\n%s' "$claimed" "$open_prs" | jq -rs '
  .[0] as $issues | .[1] as $prs |
  ($prs | map(
     (.closingIssuesReferences[].number),
     ((.title | capture("#(?<n>[0-9]+)\\)\\s*$") // null)
      | if . then (.n | tonumber) else empty end)
   )) as $covered |
  $issues | sort_by(.updatedAt) | reverse | .[] |
  select([.number] | inside($covered) | not) |
  "- #\(.number) — \(.title)
    last touched \(.updatedAt | split("T")[0])"
')

# The headline is the description's first line (docs/roadmap.md): a sentence
# split runs past a newline and breaks the layout, and truncates "i.e." besides.
release_lines=$(printf '%s' "$milestones" | jq -r '
  sort_by(.number) | .[] |
  "- \(.title): \((.description // "") | split("\n") | (.[0] // "") | if . == "" then "no headline written" else . end)
    \(.closed_issues // 0) of \((.closed_issues // 0) + (.open_issues // 0)) closed"
')

landed_lines=$(printf '%s' "$merged_prs" | jq -r "
  sort_by(.mergedAt) | reverse | .[:$landed_limit] | .[] |
  \"- #\(.number) — \(.title) (merged \(.mergedAt | split(\"T\")[0]))\"
")

# A cap that bit silently would be the same silent-wrong this replaced.
capped() {
  if [ "$(printf '%s' "$1" | jq 'length')" -ge "$2" ]; then
    echo "    (showing the first $2; there are more)"
  fi
}

section() {
  echo
  echo "$1"
  echo
  if [ -n "$2" ]; then echo "$2"; else echo "    nothing"; fi
}

echo "What's in flight — $repo, read from GitHub just now."
echo "Orientation: docs/where-we-are.md. Direction: docs/roadmap.md."

section "RELEASE (open milestones)" "$release_lines"
echo
if [ -n "$milestones_error" ]; then
  echo "    GitHub did not answer, so this section is not an answer either:"
  echo "    $milestones_error"
fi
# Once, not per milestone: the distance is repo wide and reads as that
# milestone's own burn when it sits on the row.
if [ -n "$ahead" ]; then
  echo "    $ahead commits on main since $last_tag."
elif [ -n "$tags_error" ]; then
  echo "    Could not read the tags, so there is no distance from the last"
  echo "    release: $tags_error"
fi
echo "    Cut when the headline works on the phone, then roll whatever is"
echo "    still open into the next milestone. See docs/roadmap.md."

section "IN FLIGHT (open PRs)" "$pr_lines"
capped "$open_prs" "$open_limit"

section "CLAIMED, NO PR YET (in-flight label)" "$claimed_lines"
echo
echo "    An issue here is being worked on without a PR yet, or its label"
echo "    outlived the PR that closed it, or its PR names it neither in the"
echo "    title nor with a closing keyword."
capped "$claimed" "$claimed_limit"

section "RECENTLY LANDED" "$landed_lines"
echo
