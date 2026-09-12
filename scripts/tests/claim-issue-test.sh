#!/usr/bin/env bash
# Self-test for scripts/claim-issue.sh (#1702). A fake `gh` on PATH answers
# every call the script makes so the refusal paths are exercised without
# touching GitHub: taken by label, taken by another branch's comment, taken
# by an open PR, and free.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/scripts/claim-issue.sh"

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
  "pr list")
    cat "$FIXTURES/pr_list.json" 2>/dev/null || echo '[]'
    ;;
  "issue view")
    shift
    number="$1"; shift
    q=""
    args=("$@")
    for i in "${!args[@]}"; do
      if [ "${args[$i]}" = "-q" ]; then q="${args[$((i + 1))]}"; fi
    done
    if [ "$q" = ".closedByPullRequestsReferences | length" ]; then
      cat "$FIXTURES/closers_count.txt" 2>/dev/null || echo 0
    else
      cat "$FIXTURES/issue.json" 2>/dev/null || echo '{"labels":[],"comments":[]}'
    fi
    ;;
  "issue edit")
    echo "$*" >>"$CALLS/issue_edit.log"
    ;;
  "issue comment")
    echo "$*" >>"$CALLS/issue_comment.log"
    ;;
  "project item-add")
    echo "item123"
    ;;
  "project item-edit")
    exit 0
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
  ( cd "$work/repo" && "$script" 42 )
}

expect_fail() {
  local desc="$1" needle="$2"
  mkdir -p "$CALLS"
  rm -rf "$CALLS" && mkdir -p "$CALLS"
  local out status
  set +e
  out="$(run 2>&1)"
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    fail=$((fail + 1))
    printf '✗ %s: expected refusal, script exited 0\n    output: %s\n' "$desc" "$out" >&2
    return
  fi
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf '✗ %s: refused, but message missing %q\n    output: %s\n' "$desc" "$needle" "$out" >&2
  fi
}

# ── Taken by an open PR ─────────────────────────────────────────────────────

echo '[{"number":99,"title":"Fix the thing (#42)","headRefName":"someone-elses-branch"}]' \
  >"$FIXTURES/pr_list.json"
echo 0 >"$FIXTURES/closers_count.txt"
echo '{"labels":[],"comments":[]}' >"$FIXTURES/issue.json"
expect_fail "taken by an open PR" "already mentions #42"

# ── Taken by the in-flight label plus another branch's comment ─────────────

echo '[]' >"$FIXTURES/pr_list.json"
echo 0 >"$FIXTURES/closers_count.txt"
cat >"$FIXTURES/issue.json" <<'JSON'
{"labels":[{"name":"in-flight"}],"comments":[{"body":"Claimed: branch `other-branch`, doing the thing."}]}
JSON
expect_fail "taken by another branch's comment" "already claimed on branch \`other-branch\`"

# ── Label set but no comment names a branch (ambiguous, refuse) ────────────

cat >"$FIXTURES/issue.json" <<'JSON'
{"labels":[{"name":"in-flight"}],"comments":[]}
JSON
expect_fail "label set with no identifiable owner" "check by hand"

# ── Already closed by a PR ──────────────────────────────────────────────────

echo '[]' >"$FIXTURES/pr_list.json"
echo 1 >"$FIXTURES/closers_count.txt"
echo '{"labels":[],"comments":[]}' >"$FIXTURES/issue.json"
expect_fail "already has a closing PR reference" "check whether it is done"

# ── Already claimed by this branch: idempotent, not a refusal ──────────────

echo '[]' >"$FIXTURES/pr_list.json"
echo 0 >"$FIXTURES/closers_count.txt"
cat >"$FIXTURES/issue.json" <<'JSON'
{"labels":[{"name":"in-flight"}],"comments":[{"body":"Claimed: branch `my-branch`, doing the thing."}]}
JSON
rm -rf "$CALLS" && mkdir -p "$CALLS"
out="$(run)"
if [ -f "$CALLS/issue_edit.log" ] || [ -f "$CALLS/issue_comment.log" ]; then
  fail=$((fail + 1))
  printf '✗ already claimed by this branch: should not re-label or re-comment\n' >&2
else
  pass=$((pass + 1))
fi
if printf '%s' "$out" | grep -qF "already claimed on my-branch"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf '✗ already claimed by this branch: expected a plain confirmation\n    output: %s\n' "$out" >&2
fi

# ── Free: claims it ──────────────────────────────────────────────────────────

echo '[]' >"$FIXTURES/pr_list.json"
echo 0 >"$FIXTURES/closers_count.txt"
echo '{"labels":[],"comments":[]}' >"$FIXTURES/issue.json"
rm -rf "$CALLS" && mkdir -p "$CALLS"
out="$(run)"
if grep -qF "Claimed: branch \`my-branch\`" "$CALLS/issue_comment.log" 2>/dev/null; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf '✗ free issue: expected a claim comment naming my-branch\n' >&2
fi
if grep -qF "in-flight" "$CALLS/issue_edit.log" 2>/dev/null; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf '✗ free issue: expected the in-flight label to be added\n' >&2
fi
if printf '%s' "$out" | grep -qF "claimed #42 on my-branch"; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf '✗ free issue: expected a success line\n    output: %s\n' "$out" >&2
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
