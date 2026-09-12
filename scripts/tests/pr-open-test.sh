#!/usr/bin/env bash
# Self-test for scripts/pr-open.sh (#1702 step 3): every issue number in the
# PR title must have a claim naming the current branch, or the PR does not
# open. A fake `gh` on PATH answers the claim lookup and records whether
# `gh pr create` itself was ever reached.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/scripts/pr-open.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/fixtures" "$work/calls" "$work/repo"

cat >"$work/bin/gh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

cmd="$1"; shift
sub="${1:-}"

case "$cmd $sub" in
  "repo view")
    echo "jonyardley/intrada"
    ;;
  "issue view")
    cat "$FIXTURES/issue_comment.txt" 2>/dev/null || echo ""
    ;;
  "pr create")
    echo "$*" >>"$CALLS/pr_create.log"
    echo "https://github.com/jonyardley/intrada/pull/1"
    ;;
  *)
    echo "fake gh: unhandled invocation: $cmd $sub $*" >&2
    exit 1
    ;;
esac
FAKE
chmod +x "$work/bin/gh"

export FIXTURES="$work/fixtures"
export CALLS="$work/calls"
export PATH="$work/bin:$PATH"

git -C "$work/repo" init -q -b main
git -C "$work/repo" config user.email "test@example.com"
git -C "$work/repo" config user.name "Test"
git -C "$work/repo" commit -q --allow-empty -m init
git -C "$work/repo" checkout -q -b my-branch

pass=0
fail=0

run() {
  ( cd "$work/repo" && "$script" --title "$1" --body "irrelevant" )
}

# ── No claim at all ──────────────────────────────────────────────────────────

echo "" >"$FIXTURES/issue_comment.txt"
rm -rf "$CALLS" && mkdir -p "$CALLS"
set +e
out="$(run "Fix the thing (#42)" 2>&1)"
status=$?
set -e
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF "no claim comment" && [ ! -f "$CALLS/pr_create.log" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf '✗ no claim: expected refusal before gh pr create\n    status=%s output=%s\n' "$status" "$out" >&2
fi

# ── Claimed on a different branch ───────────────────────────────────────────

echo "Claimed: branch \`other-branch\`, doing it." >"$FIXTURES/issue_comment.txt"
rm -rf "$CALLS" && mkdir -p "$CALLS"
set +e
out="$(run "Fix the thing (#42)" 2>&1)"
status=$?
set -e
if [ "$status" -ne 0 ] && printf '%s' "$out" | grep -qF "claimed on \`other-branch\`" && [ ! -f "$CALLS/pr_create.log" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf '✗ wrong branch: expected refusal naming other-branch\n    status=%s output=%s\n' "$status" "$out" >&2
fi

# ── Claimed on this branch: opens the PR ────────────────────────────────────

echo "Claimed: branch \`my-branch\`, doing it." >"$FIXTURES/issue_comment.txt"
rm -rf "$CALLS" && mkdir -p "$CALLS"
run "Fix the thing (#42)" >/dev/null
if grep -qF -- "--title Fix the thing (#42)" "$CALLS/pr_create.log" 2>/dev/null; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf '✗ claimed on this branch: expected gh pr create to run with the same args\n' >&2
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
