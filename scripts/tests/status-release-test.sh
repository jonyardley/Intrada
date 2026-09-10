#!/usr/bin/env bash
# Self-test for the RELEASE block of scripts/generate-status.sh. Puts a fake
# `gh` on PATH so the real script runs unchanged, and asserts the cases that
# would otherwise pass silently: a milestone nobody described, counts GitHub
# left out, and either read failing.
#
# The fake serves real payloads and honours --jq, so the script's own jq
# programs and its tag filter are what the assertions exercise. A fake that
# returned pre-cooked text would let a wrong field ship green.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/scripts/generate-status.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/fixtures"

cat >"$tmp/bin/gh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

jq_expr=""
args=("$@")
for i in "${!args[@]}"; do
  if [ "${args[$i]}" = "--jq" ]; then jq_expr="${args[$((i + 1))]}"; fi
done

endpoint="${2:-}"
if [ -n "${FAIL_ON:-}" ] && printf '%s' "$endpoint" | grep -q "$FAIL_ON"; then
  echo "gh: HTTP 403: API rate limit exceeded" >&2
  exit 1
fi

body='[]'
if [ "${1:-}" = "api" ]; then
  case "$endpoint" in
    *milestones*) body="$(cat "$FIXTURES/milestones.json")" ;;
    *tags*) body="$(cat "$FIXTURES/tags.json")" ;;
    *compare*) body="$(cat "$FIXTURES/compare.json")" ;;
  esac
fi

if [ -n "$jq_expr" ]; then
  printf '%s' "$body" | jq -r "$jq_expr"
else
  printf '%s' "$body"
fi
FAKE
chmod +x "$tmp/bin/gh"

export FIXTURES="$tmp/fixtures"
export PATH="$tmp/bin:$PATH"

# Newest first, as the real tags endpoint answers, and carrying a pre-release
# that must not win: a fixture in ascending order would let `tail -1` alone
# pass every assertion here.
cat >"$FIXTURES/tags.json" <<'JSON'
[{"name":"v0.11.0-rc1"},{"name":"v0.10.0"},{"name":"v0.9.0"},{"name":"v0.8.0"}]
JSON
echo '{"ahead_by":10}' >"$FIXTURES/compare.json"

pass=0
fail=0

check() {
  local haystack="$1" desc="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf '✗ %s\n    expected to find: %s\n' "$desc" "$needle" >&2
  fi
}

refute() {
  local haystack="$1" desc="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    fail=$((fail + 1))
    printf '✗ %s\n    did not expect: %s\n' "$desc" "$needle" >&2
  else
    pass=$((pass + 1))
  fi
}

# ── One milestone, described ────────────────────────────────────────────────

cat >"$FIXTURES/milestones.json" <<'JSON'
[{"number":3,"title":"v0.11.0","description":"Finish capture\nThe rest is prose. Nobody needs it here.","open_issues":4,"closed_issues":2}]
JSON
out="$("$script")"
check "$out" "prints title and headline" "- v0.11.0: Finish capture"
check "$out" "prints the burn" "2 of 6 closed"
check "$out" "measures from the last full release, not the pre-release" "10 commits on main since v0.10.0."
refute "$out" "keeps the headline to one line" "The rest is prose"

# ── A milestone nobody described ────────────────────────────────────────────

cat >"$FIXTURES/milestones.json" <<'JSON'
[{"number":3,"title":"v0.12.0","description":"","open_issues":1,"closed_issues":0},
 {"number":4,"title":"v0.13.0","description":null,"open_issues":1,"closed_issues":0}]
JSON
out="$("$script")"
check "$out" "says so when the description is empty" "v0.12.0: no headline written"
check "$out" "says so when GitHub sends no description" "v0.13.0: no headline written"

# ── Counts GitHub left out ──────────────────────────────────────────────────

cat >"$FIXTURES/milestones.json" <<'JSON'
[{"number":3,"title":"v0.11.0","description":"Finish capture"}]
JSON
out="$("$script")"
check "$out" "counts default to zero" "0 of 0 closed"
refute "$out" "never prints a null count" "null"

# ── Two open milestones ─────────────────────────────────────────────────────

cat >"$FIXTURES/milestones.json" <<'JSON'
[{"number":9,"title":"v0.10.0","description":"Capture","open_issues":0,"closed_issues":1},
 {"number":3,"title":"v0.9.0","description":"Photos","open_issues":1,"closed_issues":0}]
JSON
out="$("$script")"
# grep -F splits a multi-line pattern into alternatives, so order has to be
# compared as one string or the assertion cannot fail.
order=$(printf '%s' "$out" | grep -E '^- v[0-9]' | tr '\n' ' ')
expected="- v0.9.0: Photos - v0.10.0: Capture "
if [ "$order" = "$expected" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf '✗ orders by creation, not by title\n    saw: %s\n' "$order" >&2
fi
distance_lines=$(printf '%s' "$out" | grep -c 'commits on main since' || true)
if [ "$distance_lines" = "1" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf '✗ states the repo-wide distance once\n    saw it on %s lines\n' "$distance_lines" >&2
fi

# ── GitHub refusing each read ───────────────────────────────────────────────

cat >"$FIXTURES/milestones.json" <<'JSON'
[{"number":3,"title":"v0.11.0","description":"Finish capture","open_issues":1,"closed_issues":0}]
JSON

out="$(FAIL_ON=milestones "$script")"
check "$out" "names a milestones outage rather than showing an empty section" "GitHub did not answer"
check "$out" "keeps the rest of the report" "RECENTLY LANDED"

out="$(FAIL_ON=tags "$script")"
check "$out" "survives a tags outage" "- v0.11.0: Finish capture"
check "$out" "names the tags outage" "Could not read the tags"
refute "$out" "claims no distance it cannot measure" "commits on main since"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
