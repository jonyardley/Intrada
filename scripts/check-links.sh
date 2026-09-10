#!/usr/bin/env bash
# Fail a branch that leaves a markdown link pointing at a path that does not
# exist (#1597). Nothing else reads link targets, so the next reader to follow
# one is usually an agent mid-task that then plans around a document it could
# not open. Two halves, because the fault arrives from both ends:
#
#   1. Links added on changed lines, scoped the same diff-aware way
#      check-dashes.sh is, so new content binds without demanding a clean sweep
#      of every historical link first.
#   2. Files the branch deletes or renames, still linked from anywhere in the
#      tree. That is the half a changed-lines check cannot see, and it is the
#      one that has actually bitten: the rename moves, the pointers do not.
#
# External URLs are skipped: they need the network and go stale on someone
# else's schedule. Bypass a genuinely justified case with SKIP_LINK_CHECK=1.

set -euo pipefail

if [ "${SKIP_LINK_CHECK:-}" = "1" ]; then
  exit 0
fi

cd "$(git rev-parse --show-toplevel)"

# CI passes the PR base via LINK_CHECK_BASE (HEAD is detached on a PR
# checkout). Locally the recipe leaves it unset and we derive origin/main.
base="${LINK_CHECK_BASE:-}"
if [ -z "$base" ]; then
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
  if [ -z "$branch" ]; then
    exit 0
  fi
  case "$branch" in
    main | master) exit 0 ;;
  esac
  base="origin/main"
fi

if ! git rev-parse --verify "$base" >/dev/null 2>&1; then
  exit 0
fi

# The merge base with no second commit, so the diff runs to the working tree
# rather than to HEAD. Line numbers and file content then come from the same
# tree: against HEAD, one uncommitted edit above a link renumbers every line
# below it and the check blames whatever now sits on the old number. It also
# means an uncommitted link is checked, which is where a link is written.
mb=$(git merge-base "$base" HEAD 2>/dev/null || true)
if [ -z "$mb" ]; then
  exit 0
fi

range="$mb"

# ── Reading a markdown file ─────────────────────────────────────────────────

# $1 the file, $2 non-zero to read every line rather than the line numbers on
# stdin. Fenced blocks and inline code spans are stripped, so a link written as
# an example is not read as a claim about the tree.
link_targets() {
  awk -v all="${2:-0}" '
    NR == FNR && all == 0 { want[$1 + 0] = 1; next }
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    all == 0 && !want[FNR] { next }
    {
      line = $0
      gsub(/`[^`]*`/, "", line)
      rest = line
      while (match(rest, /\]\([^)]*\)/)) {
        print FNR "\t" substr(rest, RSTART + 2, RLENGTH - 3)
        rest = substr(rest, RSTART + RLENGTH)
      }
      if (match(line, /^[[:space:]]*\[[^]]+\]:[[:space:]]*[^[:space:]]+/)) {
        def = substr(line, RSTART, RLENGTH)
        sub(/^[[:space:]]*\[[^]]+\]:[[:space:]]*/, "", def)
        print FNR "\t" def
      }
    }
  ' - "$1"
}

# $1 the raw target, $2 the linking file's directory. Prints the path to test,
# or nothing when the target is not a local path this check can resolve.
resolve_target() {
  local target="$1"

  # A title after the path ([text](path "Title")) is not part of the target.
  target=${target%%[[:space:]]*}
  target=${target#<}
  target=${target%>}
  # An anchor on the target, or a link to a heading in the same file: this
  # check reads existence only.
  target=${target%%#*}
  [ -n "$target" ] || return 0

  case "$target" in
    # A protocol-relative host, or a templated path nothing can resolve.
    //* | *'{'* | *'}'* | *'$'* | *'<'* | *'>'* | *'*'*) return 0 ;;
  esac

  # Any scheme (http:, https:, mailto:, tel:) is somebody else's server.
  if [[ $target =~ ^[A-Za-z][A-Za-z0-9+.-]*: ]]; then
    return 0
  fi

  target=${target//%20/ }

  if [ "${target#/}" != "$target" ]; then
    printf '%s' ".${target}"
  else
    printf '%s' "$2/$target"
  fi
}

found=0
checked=0
added_report=""
stale_report=""
seen="|"

# ── Links added on changed lines ────────────────────────────────────────────

changed=$(git diff "$range" --name-only --diff-filter=ACMR -- '*.md' 2>/dev/null || true)

while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue

  # -U0 so every line in a hunk is an addition or a deletion, which is what
  # lets the counter below track new-file line numbers by itself. The `+++`
  # header arrives before any hunk, so the unset counter skips it: matching on
  # `+++` instead would eat an added line that starts with one.
  added=$(git diff -U0 "$range" -- "$f" | awk '
    /^@@/ {
      if (match($0, /\+[0-9]+/)) { n = substr($0, RSTART + 1, RLENGTH - 1) + 0 }
      next
    }
    /^\+/ { if (n != "") { print n; n++ } }
  ')
  [ -n "$added" ] || continue

  dir=$(dirname "$f")

  while IFS=$'\t' read -r lineno target; do
    [ -n "${target:-}" ] || continue
    resolved=$(resolve_target "$target" "$dir")
    [ -n "$resolved" ] || continue
    checked=$((checked + 1))
    seen="$seen$f:$lineno|"
    if [ ! -e "$resolved" ]; then
      found=1
      added_report="$added_report"$'\n'"  $f:$lineno points at $target"
    fi
  done < <(printf '%s\n' "$added" | link_targets "$f")
done <<EOF
$changed
EOF

# ── Files the branch removed, still linked ──────────────────────────────────

# --name-status so a rename yields the path that went away, which --name-only
# would report as the path it became.
removed=$(git diff "$range" --name-status --diff-filter=DR 2>/dev/null | awk -F'\t' '$1 ~ /^[DR]/ { print $2 }' || true)

if [ -n "$removed" ]; then
  removed_names=$(printf '%s\n' "$removed" | sed 's|.*/||' | sort -u)

  while IFS= read -r f; do
    [ -f "$f" ] || continue
    dir=$(dirname "$f")
    while IFS=$'\t' read -r lineno target; do
      [ -n "${target:-}" ] || continue
      resolved=$(resolve_target "$target" "$dir")
      [ -n "$resolved" ] || continue
      if [ -e "$resolved" ]; then
        continue
      fi
      case "$seen" in
        *"|$f:$lineno|"*) continue ;;
      esac
      if printf '%s\n' "$removed_names" | grep -qxF "${resolved##*/}"; then
        found=1
        stale_report="$stale_report"$'\n'"  $f:$lineno points at $target"
      fi
    done < <(link_targets "$f" 1 </dev/null)
  done < <(git ls-files '*.md')
fi

# ── The verdict ─────────────────────────────────────────────────────────────

if [ "$found" = "1" ]; then
  printf '\nBlocked: this branch leaves a markdown link pointing at a path that does not exist.\n' >&2
  if [ -n "$added_report" ]; then
    printf '\nAdded on a changed line:\n%s\n' "$added_report" >&2
  fi
  if [ -n "$stale_report" ]; then
    printf '\nStill pointing at a file this branch removed or renamed:\n%s\n' "$stale_report" >&2
  fi
  cat <<EOF >&2

Paths resolve from the linking file's own directory, or from the repo root
when they start with a slash. Fix the target, or point at what replaced it.

If a case is genuinely justified (a path a later commit creates), bypass with:

  SKIP_LINK_CHECK=1 just hygiene

EOF
  exit 1
fi

if [ -n "$removed" ]; then
  echo "✓ links: $checked on changed lines resolve, and nothing links the $(printf '%s\n' "$removed" | wc -l | tr -d ' ') path(s) this branch removed"
else
  echo "✓ links: $checked local markdown link(s) on changed lines resolve"
fi
exit 0
