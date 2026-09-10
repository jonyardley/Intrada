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
# so "is a release due" is only answerable next to the burn. Both halves read
# GitHub like everything else here.
milestones=$(gh api "repos/$repo/milestones?state=open" 2>/dev/null || echo '[]')
last_tag=$(gh api "repos/$repo/tags?per_page=100" \
  --jq '.[].name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' 2>/dev/null |
  sort -V | tail -1)
ahead=""
if [ -n "$last_tag" ]; then
  ahead=$(gh api "repos/$repo/compare/$last_tag...main" --jq '.ahead_by' 2>/dev/null || echo "")
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

# The description's first sentence is the headline, so a milestone whose
# description nobody wrote prints its title and nothing to cut on.
release_lines=$(printf '%s' "$milestones" | jq -r --arg tag "$last_tag" --arg ahead "$ahead" '
  sort_by(.title) | .[] |
  "- \(.title): \((.description // "") | split(". ") | (.[0] // "") | if . == "" then "no headline written" else . end)
    \(.closed_issues) of \(.closed_issues + .open_issues) closed"
  + (if $ahead != "" and $tag != "" then ", \($ahead) commits on main since \($tag)" else "" end)
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
