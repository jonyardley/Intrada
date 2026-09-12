#!/usr/bin/env bash
# Snapshot hygiene guard (see .claude/rules/ios-quality.md).
#
#  1. Orphans: every __Snapshots__/<Class>/<method>.N.png must map to a
#     `func <method>` in ios/IntradaTests/<Class>.swift. A renamed or deleted
#     test leaves a dead PNG that bloats git history forever — fail so it's
#     pruned with the test.
#  2. Size ceiling: a reference over SNAPSHOT_MAX_BYTES is almost always an
#     un-optimized PNG (Xcode writes a redundant all-opaque alpha channel;
#     `just ios-snapshots-optimize` strips it losslessly, ~75% smaller). Fail so
#     it's optimized before it lands, keeping per-record history growth low.
set -euo pipefail

ROOT="ios/IntradaTests"
SNAP_DIR="$ROOT/__Snapshots__"
MAX_BYTES="${SNAPSHOT_MAX_BYTES:-200000}"
# References that stay large as lossless PNG even after `oxipng -o max -Z`:
# smooth gradients (Practice one-tap hero, Focus player radial, the Up next
# hero's card-level reference), dense-control screens (Session summary's
# per-item score-pill rows over the gold gradient toast), and one
# accessibility-size screen whose bill is glyphs rather than gradient (the
# session detail at .accessibility3 fills the frame with large text, and
# `oxipng` leaves it byte-identical). They get a higher bound. Keep this list
# TIGHT: add only a reference proven irreducible, with the reason. Cropping
# does not help the gradients: flat paper costs almost nothing and the gradient
# is the whole bill, which is why a component crop is on the list alongside the
# full screens.
LARGE_MAX_BYTES="${SNAPSHOT_LARGE_MAX_BYTES:-300000}"
is_large() {
  case "$1" in
    testPracticeScreen | testPracticeScreenPopulated | testPracticeScreenPriorities | \
      testPracticeScreenQuietDay | testPracticeScreenSuggestionDismissed | \
      testPracticeScreenSuggestionDismissedPriorities | testPracticeScreenGreeting | \
      testUpNextHeroNeverMarked | \
      testFocusPlayerWithReps | testFocusPlayerWithTarget | testFocusPlayerLongSession | \
      testPracticeSessionDetailAccessibilitySize | \
      testSessionSummaryCompleted | testSessionSummaryWithReflection) return 0 ;;
    *) return 1 ;;
  esac
}

# One tier above `is_large`: the Up next hero (#1082) is the largest unbroken
# gradient the app draws — over half a full-screen reference — so it clears the
# 300k bound even fully optimized. Keep this bucket to references that are
# mostly one gradient; anything else belongs in `is_large` or under the default.
XL_MAX_BYTES="${SNAPSHOT_XL_MAX_BYTES:-420000}"
is_xl() {
  case "$1" in
    testPracticeScreenSuggestion | testPracticeScreenSuggestionPriorities) return 0 ;;
    *) return 1 ;;
  esac
}

[ -d "$SNAP_DIR" ] || { echo "no snapshots dir; nothing to check"; exit 0; }

fail=0
while IFS= read -r png; do
  cls=$(basename "$(dirname "$png")")
  method=$(basename "$png" | cut -d. -f1)
  swift="$ROOT/$cls.swift"
  if [ ! -f "$swift" ] || ! grep -qE "func[[:space:]]+$method[[:space:]]*\(" "$swift"; then
    echo "::error file=$png::orphan snapshot — no 'func $method' in $swift (delete the PNG or restore the test)"
    fail=1
  fi
  ceiling="$MAX_BYTES"
  is_large "$method" && ceiling="$LARGE_MAX_BYTES"
  is_xl "$method" && ceiling="$XL_MAX_BYTES"
  size=$(wc -c < "$png" | tr -d ' ')
  if [ "$size" -gt "$ceiling" ]; then
    echo "::error file=$png::$size bytes > $ceiling ceiling — run 'just ios-snapshots-optimize' (or raise SNAPSHOT_MAX_BYTES if genuinely large)"
    fail=1
  fi
done < <(find "$SNAP_DIR" -name '*.png')

if [ "$fail" -eq 0 ]; then
  echo "ok: all snapshot references map to a test and are within $MAX_BYTES bytes"
fi
exit "$fail"
