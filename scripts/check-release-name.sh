#!/usr/bin/env bash
# The Sentry release name is a contract across two files that nothing else
# reads together (#1611): the app composes it at runtime, and the release lane
# composes it off the uploaded binary, both from the same three Info.plist
# fields. Swap a separator on one side and crashes arrive filed under a release
# nobody created, which reads as Sentry being odd rather than as a one-character
# edit. This resolves each side to the keys it reads and the separators it joins
# them with, so renaming a local variable or reflowing either file is fine and
# only a real disagreement fails.
#
# The two file paths are overridable so the self-test can point the same parser
# at fixtures that disagree (scripts/tests/hygiene-checks-test.sh).

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

swift_file="${RELEASE_NAME_SWIFT:-ios/Intrada/Core/SentryRelease.swift}"
workflow_file="${RELEASE_NAME_WORKFLOW:-.github/workflows/release-testflight.yml}"

contract="CFBundleIdentifier@CFBundleShortVersionString+CFBundleVersion"

fail() {
  printf '\nBlocked: %s\n\n' "$1" >&2
  cat <<EOF >&2
The release name must be composed the same way in both:

  $swift_file
  $workflow_file

as the bundle identifier, then the short version, then the build number,
joined by an at sign and a plus ($contract).

If the format is changing deliberately, change both sides and the contract
line in scripts/check-release-name.sh together.

EOF
  exit 1
}

for f in "$swift_file" "$workflow_file"; do
  [ -f "$f" ] || fail "$f is missing, so the release name contract cannot be read."
done

# ── The app side ────────────────────────────────────────────────────────────

# Flattened, so a reformat that wraps the arguments differently still reads.
swift_flat=$(tr '\n\t' '  ' <"$swift_file" | tr -s ' ')

swift_literal_re='"\\\(([A-Za-z0-9_]+)\)([^"\\]*)\\\(([A-Za-z0-9_]+)\)([^"\\]*)\\\(([A-Za-z0-9_]+)\)"'
swift_hits=$({ printf '%s' "$swift_flat" | grep -oE "$swift_literal_re" || true; } | wc -l | tr -d ' ')
if [ "$swift_hits" != "1" ]; then
  fail "$swift_file holds $swift_hits string literals composing three fields, not exactly one."
fi

[[ $swift_flat =~ $swift_literal_re ]] || fail "$swift_file composes no three-field release name."
swift_parts=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}" "${BASH_REMATCH[5]}")

# Every `var:` in the file, not the first: the declaration names the same
# labels as the call site that reads the plist, and only the latter carries a key.
swift_key_for() {
  local var="$1" seg
  while IFS= read -r seg; do
    case "$seg" in
      *'"CF'*)
        printf '%s' "$seg" | grep -oE '"CF[A-Za-z]+"' | tr -d '"' | head -1
        return 0
        ;;
      *bundleIdentifier*)
        printf '%s' 'CFBundleIdentifier'
        return 0
        ;;
    esac
  done < <(printf '%s' "$swift_flat" | grep -oE "[^A-Za-z0-9_]$var:[^,)]*" || true)
  fail "$swift_file interpolates $var into the release name but reads no Info.plist key into it."
}

# One substitution per assignment: an assignment takes only the last one's
# status, so a combined line would swallow an early resolution failure.
swift_k1=$(swift_key_for "${swift_parts[0]}")
swift_k2=$(swift_key_for "${swift_parts[2]}")
swift_k3=$(swift_key_for "${swift_parts[4]}")
swift_name="${swift_k1}${swift_parts[1]}${swift_k2}${swift_parts[3]}${swift_k3}"

# ── The release lane side ───────────────────────────────────────────────────

lane_assign_re='release="[^"]*"'
lane_hits=$({ grep -oE "$lane_assign_re" "$workflow_file" || true; } | wc -l | tr -d ' ')
if [ "$lane_hits" != "1" ]; then
  fail "$workflow_file holds $lane_hits release name assignments, not exactly one."
fi

lane_assign=$(grep -oE "$lane_assign_re" "$workflow_file")
lane_re='^release="\$\{?([A-Za-z0-9_]+)\}?([^$]*)\$\{?([A-Za-z0-9_]+)\}?([^$]*)\$\{?([A-Za-z0-9_]+)\}?"$'
[[ $lane_assign =~ $lane_re ]] || fail "$workflow_file composes the release name from something other than three shell variables: $lane_assign"
lane_parts=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}" "${BASH_REMATCH[5]}")

lane_key_for() {
  local var="$1" key
  key=$(grep -E "^[[:space:]]*$var=" "$workflow_file" | head -1 | grep -oE 'CF[A-Za-z]+' | head -1 || true)
  if [ -z "$key" ]; then
    fail "$workflow_file interpolates \$$var into the release name but reads no Info.plist key into it."
  fi
  printf '%s' "$key"
}

lane_k1=$(lane_key_for "${lane_parts[0]}")
lane_k2=$(lane_key_for "${lane_parts[2]}")
lane_k3=$(lane_key_for "${lane_parts[4]}")
lane_name="${lane_k1}${lane_parts[1]}${lane_k2}${lane_parts[3]}${lane_k3}"

# ── The comparison ──────────────────────────────────────────────────────────

if [ "$swift_name" != "$lane_name" ]; then
  fail "the two sides disagree. The app composes $swift_name and the lane composes $lane_name."
fi

if [ "$swift_name" != "$contract" ]; then
  fail "both sides compose $swift_name, which is not the pinned contract $contract."
fi

echo "✓ release name: both sides compose $contract"
exit 0
