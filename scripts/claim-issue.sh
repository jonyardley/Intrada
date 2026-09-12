#!/usr/bin/env bash
# Claim an issue before building it, refusing if someone already has: the
# in-flight label is already set, the newest "Claimed" comment names another
# branch, or an open PR already references it (#1702). Before this, adding
# the label to an already-labelled issue succeeded silently and a claim
# comment could land on top of another session's — two sessions built the
# same greeting on 2026-09-11 (#1694) because nothing caught either.
#
# Called via `just claim <number>`.

set -euo pipefail

usage() {
  echo "Usage: $0 <issue-number>" >&2
  exit 1
}

[ $# -eq 1 ] || usage
number="$1"

project_number="2"
project_owner="jonyardley"
project_id="PVT_kwHOAAr6vs4A1_pq"
project_status_field="PVTSSF_lAHOAAr6vs4A1_pqzgrX99A"
project_status_in_progress="47fc9ee4"

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
branch="$(git rev-parse --abbrev-ref HEAD)"

if [ "$branch" = "main" ]; then
  echo "✗ on main: create the feature branch first, so the claim comment names it." >&2
  exit 1
fi

open="$(gh pr list --repo "$repo" --state open --search "$number" --json number,title,headRefName)"
if [ "$(printf '%s' "$open" | jq 'length')" -ne 0 ]; then
  echo "✗ an open PR already mentions #$number:" >&2
  printf '%s' "$open" | jq -r '.[] | "    #\(.number) \(.title) (\(.headRefName))"' >&2
  echo "  Stop and read it before implementing the same thing twice." >&2
  exit 1
fi

closers="$(gh issue view "$number" --repo "$repo" --json closedByPullRequestsReferences -q '.closedByPullRequestsReferences | length')"
if [ "$closers" != "0" ]; then
  echo "✗ #$number already has $closers closing PR reference(s): check whether it is done." >&2
  exit 1
fi

# The newest comment whose body opens with "Claimed" names the current owner;
# a withdrawal or release comment does not start that way, so it is never
# mistaken for a live claim. The branch is the first backticked token in it.
issue="$(gh issue view "$number" --repo "$repo" --json labels,comments)"
has_label="$(printf '%s' "$issue" | jq -r '([.labels[].name] | index("in-flight")) != null')"
claim_body="$(printf '%s' "$issue" | jq -r '[.comments[] | select(.body | test("^Claimed"; "i"))] | last | .body // empty')"
claim_branch="$(printf '%s' "$claim_body" | grep -oE '`[^`]+`' | head -1 | tr -d '`' || true)"

if [ -n "$claim_branch" ] && [ "$claim_branch" != "$branch" ]; then
  echo "✗ #$number is already claimed on branch \`$claim_branch\`." >&2
  exit 1
fi

if [ "$has_label" = "true" ] && [ -z "$claim_branch" ]; then
  echo "✗ #$number already carries in-flight but no claim comment names a branch: check by hand." >&2
  exit 1
fi

if [ "$has_label" = "true" ] && [ "$claim_branch" = "$branch" ]; then
  echo "✓ #$number is already claimed on $branch"
  exit 0
fi

gh issue edit "$number" --repo "$repo" --add-label in-flight
gh issue comment "$number" --repo "$repo" --body "Claimed: branch \`$branch\`."

item="$(gh project item-add "$project_number" --owner "$project_owner" \
  --url "https://github.com/$repo/issues/$number" --format json -q .id 2>/dev/null || true)"
if [ -n "$item" ] && gh project item-edit --id "$item" --project-id "$project_id" \
  --field-id "$project_status_field" \
  --single-select-option-id "$project_status_in_progress" >/dev/null 2>&1; then
  echo "✓ board: #$number is In progress"
else
  echo "! board not updated; the token needs project scope: gh auth refresh -s project" >&2
fi

echo "✓ claimed #$number on $branch"
