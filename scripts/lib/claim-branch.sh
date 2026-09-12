#!/usr/bin/env bash
# Shared by claim-issue.sh, pr-open.sh and session-claims.sh: pull the
# claimed branch out of a "Claimed" comment body. Matches the backtick
# format going forward ("Claimed: branch `name`, ...") and the plain-text
# format already live on #1692 and #1694 ("Claimed. Branch: name (...)"),
# since either check would otherwise lock out issues claimed before #1702
# shipped. Looks specifically for the word "branch" rather than the first
# backticked token in the body, so a later backticked phrase in the same
# comment is never mistaken for the branch name.
claim_branch_from_body() {
  local body="$1" branch
  branch="$(grep -oiE 'branch:?[[:space:]]*`[^`]+`' <<<"$body" | head -1 |
    grep -oE '`[^`]+`' | tr -d '`' || true)"
  if [ -z "$branch" ]; then
    branch="$(grep -oiE 'branch:?[[:space:]]+[A-Za-z0-9_./-]+' <<<"$body" | head -1 |
      sed -E 's/^[Bb]ranch:?[[:space:]]+//' || true)"
  fi
  printf '%s' "$branch"
}
