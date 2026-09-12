#!/usr/bin/env bash
# Self-test for scripts/session-claims.sh (#1703): lists in-flight issues
# with their claimed branch and open PR, caches the result for a few
# minutes, and stays silent when gh is unavailable.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/scripts/session-claims.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/repo"

cat >"$work/bin/gh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

cmd="$1"; shift
sub="${1:-}"

case "$cmd $sub" in
  "issue list")
    echo '[{"number":42,"title":"Fix the thing"},{"number":43,"title":"Do the other thing"}]'
    ;;
  "pr list")
    echo '[{"number":7,"closingIssuesReferences":[{"number":43}]}]'
    ;;
  "issue view")
    number="$2"
    if [ "$number" = "42" ]; then
      echo "Claimed: branch \`branch-a\`, doing it."
    else
      echo "Claimed: branch \`branch-b\`, doing it."
    fi
    ;;
  *)
    echo "fake gh: unhandled invocation: $cmd $sub $*" >&2
    exit 1
    ;;
esac
FAKE
chmod +x "$work/bin/gh"

git -C "$work/repo" init -q -b main
git -C "$work/repo" config user.email "test@example.com"
git -C "$work/repo" config user.name "Test"
git -C "$work/repo" commit -q --allow-empty -m init

pass=0
fail=0

check() {
  local haystack="$1" desc="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf '✗ %s\n    expected to find: %s\n    saw: %s\n' "$desc" "$needle" "$haystack" >&2
  fi
}

# ── Lists both issues, one with a PR, one without ───────────────────────────

out="$(cd "$work/repo" && PATH="$work/bin:$PATH" INTRADA_CLAIMS_CACHE_TTL=180 "$script")"
check "$out" "names the unclaimed-PR issue and its branch" "#42 — Fix the thing"
check "$out" "names its branch" "branch branch-a"
check "$out" "names the second issue's branch" "branch branch-b"
check "$out" "names its open PR" "PR #7"

# ── Serves from cache within the TTL, without calling gh again ─────────────

echo "gh: should not run again" >"$work/bin/gh"
chmod +x "$work/bin/gh"
cached_out="$(cd "$work/repo" && PATH="$work/bin:$PATH" INTRADA_CLAIMS_CACHE_TTL=180 "$script")"
if [ "$cached_out" = "$out" ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf '✗ cache: expected the cached output unchanged\n    saw: %s\n' "$cached_out" >&2
fi

# ── Silent when gh is missing ────────────────────────────────────────────────
# A PATH with no `gh` at all, not just one without the fake — the machine
# running this test may have a real gh installed elsewhere on PATH.

empty_bin="$work/empty-bin"
mkdir -p "$empty_bin"
for tool in bash git date stat cat grep mkdir; do
  path="$(command -v "$tool")"
  ln -s "$path" "$empty_bin/$tool"
done

missing_out="$(cd "$work/repo" && PATH="$empty_bin" "$script" 2>&1)"
status=0
( cd "$work/repo" && PATH="$empty_bin" "$script" ) || status=$?
if [ -z "$missing_out" ] && [ "$status" -eq 0 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf '✗ offline: expected silent success, got status=%s output=%s\n' "$status" "$missing_out" >&2
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
