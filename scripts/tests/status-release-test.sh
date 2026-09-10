#!/usr/bin/env bash
# Self-test for the RELEASE block of scripts/generate-status.sh. Puts a fake
# `gh` on PATH so the real script runs unchanged against fixtures, and asserts
# the three cases that would otherwise fail silently: a milestone with a
# headline, one whose description nobody wrote, and no open milestone at all.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/scripts/generate-status.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/fixtures"

cat >"$tmp/bin/gh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  pr|issue) echo '[]' ;;
  api)
    case "${2:-}" in
      *milestones*) cat "$FIXTURES/milestones.json" ;;
      *tags*) printf 'v0.9.0\nv0.10.0\n' ;;
      *compare*) echo 10 ;;
      *) echo '[]' ;;
    esac
    ;;
  *) echo '[]' ;;
esac
FAKE
chmod +x "$tmp/bin/gh"

export FIXTURES="$tmp/fixtures"
export PATH="$tmp/bin:$PATH"

pass=0
fail=0

check() {
  local haystack="$1" desc="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf '✗ %s\n    expected to find: %s\n' "$desc" "$needle" >&2
  fi
}

refute() {
  local haystack="$1" desc="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    fail=$((fail + 1))
    printf '✗ %s\n    did not expect: %s\n' "$desc" "$needle" >&2
  else
    pass=$((pass + 1))
  fi
}

# ── A milestone with a headline ─────────────────────────────────────────────

cat >"$FIXTURES/milestones.json" <<'JSON'
[{"title":"v0.11.0","description":"Finish capture. The rest is prose nobody needs here.","open_issues":4,"closed_issues":2}]
JSON
out="$("$script")"
check "$out" "prints the milestone title" "v0.11.0: Finish capture"
check "$out" "prints the burn" "2 of 6 closed"
check "$out" "prints commits since the last tag" "10 commits on main since v0.10.0"
refute "$out" "stops at the first sentence" "prose nobody needs"

# ── A milestone nobody described ────────────────────────────────────────────

cat >"$FIXTURES/milestones.json" <<'JSON'
[{"title":"v0.12.0","description":"","open_issues":1,"closed_issues":0},
 {"title":"v0.13.0","description":null,"open_issues":1,"closed_issues":0}]
JSON
out="$("$script")"
check "$out" "says so when the description is empty" "v0.12.0: no headline written"
check "$out" "says so when GitHub returns no description at all" "v0.13.0: no headline written"

# ── No open milestone ───────────────────────────────────────────────────────

echo '[]' >"$FIXTURES/milestones.json"
out="$("$script")"
check "$out" "keeps the section with nothing in it" "RELEASE (open milestones)"
refute "$out" "invents no milestone" "no headline written"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
