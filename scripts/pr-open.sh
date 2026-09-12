#!/usr/bin/env bash
# Wrap `gh pr create`, refusing when an issue number in the title has no
# claim naming this branch (#1702 step 3): a session that inherited an issue
# from its brief without running `just claim` is the second way the
# 2026-09-11 duplicate (#1694) happened, and the claim step alone cannot
# catch that.
#
# Called via `just pr-open -- <gh pr create args>`.

set -euo pipefail

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
branch="$(git rev-parse --abbrev-ref HEAD)"

title=""
args=("$@")
for i in "${!args[@]}"; do
  if [ "${args[$i]}" = "--title" ] || [ "${args[$i]}" = "-t" ]; then
    title="${args[$((i + 1))]}"
  fi
done

if [ -z "$title" ]; then
  echo "✗ pr-open needs an explicit --title (the issue-number check has nothing to read otherwise)." >&2
  exit 1
fi

numbers="$(grep -oE '#[0-9]+' <<<"$title" | tr -d '#' | sort -u || true)"
for n in $numbers; do
  claim_branch="$(gh issue view "$n" --repo "$repo" --json comments -q \
    '[.comments[] | select(.body | test("^Claimed"; "i"))] | last | .body // empty' |
    grep -oE '`[^`]+`' | head -1 | tr -d '`' || true)"
  if [ -z "$claim_branch" ]; then
    echo "✗ #$n has no claim comment naming a branch: run \`just claim $n\` first." >&2
    exit 1
  fi
  if [ "$claim_branch" != "$branch" ]; then
    echo "✗ #$n is claimed on \`$claim_branch\`, not \`$branch\`: check before opening this PR." >&2
    exit 1
  fi
done

gh pr create "${args[@]}"
