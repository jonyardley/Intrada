#!/usr/bin/env bash
# Claim an issue before building it, refusing if someone already has: the
# newest "Claimed" comment names another branch, the in-flight label is set
# with no comment to identify an owner, or an open PR on a different branch
# already references it (#1702). Before this, adding the label to an
# already-labelled issue succeeded silently and a claim comment could land
# on top of another session's: two sessions built the same greeting on
# 2026-09-11 (#1694) because nothing caught either.
#
# Called via `just claim <number>`.

set -euo pipefail

usage() {
  echo "Usage: $0 <issue-number>" >&2
  exit 1
}

[ $# -eq 1 ] || usage
number="$1"
case "$number" in
  '' | *[!0-9]*) usage ;;
esac

lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/claim-branch.sh
source "$lib_dir/lib/claim-branch.sh"

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

# A PR already open on THIS branch is the resumed-session case (a handover
# picking the work back up), not a duplicate: only another branch's open PR
# is a conflict.
open="$(gh pr list --repo "$repo" --state open --search "$number" --json number,title,headRefName |
  jq --arg b "$branch" '[.[] | select(.headRefName != $b)]')"
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
# mistaken for a live claim.
issue="$(gh issue view "$number" --repo "$repo" --json labels,comments)"
has_label="$(printf '%s' "$issue" | jq -r '([.labels[].name] | index("in-flight")) != null')"
claim_body="$(printf '%s' "$issue" | jq -r '[.comments[] | select(.body | test("^Claimed"; "i"))] | last | .body // empty')"
claim_branch="$(claim_branch_from_body "$claim_body")"

if [ -n "$claim_branch" ] && [ "$claim_branch" = "$branch" ]; then
  # Already ours: make sure the label is set (a retry after a failed label
  # add lands here) but never re-post the claim comment.
  if [ "$has_label" != "true" ]; then
    gh issue edit "$number" --repo "$repo" --add-label in-flight
  fi
  echo "✓ #$number is already claimed on $branch"
  exit 0
fi

if [ -n "$claim_branch" ]; then
  echo "✗ #$number is already claimed on branch \`$claim_branch\`." >&2
  echo "  If that work has genuinely stopped, post a fresh \"Claimed: branch \`$branch\`\" comment" >&2
  echo "  (or delete the old one) and drop the in-flight label by hand, then retry." >&2
  exit 1
fi

if [ "$has_label" = "true" ]; then
  echo "✗ #$number already carries in-flight but no claim comment names a branch: check by hand." >&2
  exit 1
fi

# Comment before label: if the comment lands and the label add then fails
# (network blip, permissions), a retry sees claim_branch == branch above and
# recovers by adding the label alone, rather than wedging with a label and no
# comment to identify the owner.
gh issue comment "$number" --repo "$repo" --body "Claimed: branch \`$branch\`."
gh issue edit "$number" --repo "$repo" --add-label in-flight

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
