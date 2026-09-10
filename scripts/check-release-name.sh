#!/usr/bin/env bash
# The Sentry release name is a contract across two files that nothing else
# reads together (#1611): the app composes it at runtime, and the release lane
# composes it off the uploaded binary, both from the same three Info.plist
# fields. Swap a separator on one side and crashes arrive filed under a release
# nobody created, which reads as Sentry being odd rather than as a one-character
# edit.
#
# The lane is read all the way through: its variables are resolved back to the
# keys they were read from, so renaming one or reindenting the block is fine.
# The app is read for shape and fields only, deliberately. Resolving its
# interpolated names back to keys the same way was tried, and it failed on an
# ordinary tidy (hoisting the plist reads into locals), which is the false
# failure #1611 says is worse than no check at all. What the app composes is
# already pinned by ios/IntradaTests/SentryReleaseTests.swift; what nothing
# else reads is whether the two files still agree.
#
# So one gap is knowingly left: the app swapping which of its two version keys
# feeds which argument passes here, because both keys are still read and the
# literal is unchanged. Every other way the two can drift apart fails.
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

# ── The contract, read once ─────────────────────────────────────────────────

contract_re='^([A-Za-z]+)([^A-Za-z])([A-Za-z]+)([^A-Za-z])([A-Za-z]+)$'
[[ $contract =~ $contract_re ]] || fail "the contract line in this script is not three fields and two separators."
contract_sep1="${BASH_REMATCH[2]}"
contract_sep2="${BASH_REMATCH[4]}"
contract_keys=$(printf '%s\n%s\n%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[5]}" | sort | tr '\n' ' ')

# ── The app side: shape and fields ──────────────────────────────────────────

# Flattened, so a reformat that wraps the arguments differently still reads.
swift_flat=$(tr '\n\t' '  ' <"$swift_file" | tr -s ' ')

swift_literal_re='"\\\(([A-Za-z0-9_]+)\)([^"\\]*)\\\(([A-Za-z0-9_]+)\)([^"\\]*)\\\(([A-Za-z0-9_]+)\)"'
swift_hits=$({ printf '%s' "$swift_flat" | grep -oE "$swift_literal_re" || true; } | wc -l | tr -d ' ')
if [ "$swift_hits" != "1" ]; then
  fail "$swift_file holds $swift_hits string literals composing three fields, not exactly one."
fi

[[ $swift_flat =~ $swift_literal_re ]] || fail "$swift_file composes no three-field release name."
swift_sep1="${BASH_REMATCH[2]}"
swift_sep2="${BASH_REMATCH[4]}"

if [ "$swift_sep1" != "$contract_sep1" ] || [ "$swift_sep2" != "$contract_sep2" ]; then
  fail "$swift_file joins the three fields with '$swift_sep1' and '$swift_sep2', not '$contract_sep1' and '$contract_sep2'."
fi

# bundle.bundleIdentifier is Foundation's accessor for CFBundleIdentifier, so
# it counts as reading that key.
swift_keys=$({ printf '%s' "$swift_flat" | grep -oE 'bundleIdentifier|"CF[A-Za-z]+"' || true; } |
  tr -d '"' | sed 's/^bundleIdentifier$/CFBundleIdentifier/' | sort -u | tr '\n' ' ')

if [ "$swift_keys" != "$contract_keys" ]; then
  fail "$swift_file reads the identity fields [ ${swift_keys}], not [ ${contract_keys}]."
fi

# ── The release lane side: resolved in full ─────────────────────────────────

# Whole lines only, so a `note_release=` elsewhere in a 200 line workflow is
# not read as a second attempt at the same assignment.
lane_lines=$({ grep -E '^[[:space:]]*release="[^"]*"[[:space:]]*$' "$workflow_file" || true; } |
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
lane_hits=$(printf '%s\n' "$lane_lines" | grep -c . || true)
if [ "$lane_hits" != "1" ]; then
  fail "$workflow_file holds $lane_hits lines assigning the release name, not exactly one."
fi

lane_assign=$(printf '%s\n' "$lane_lines" | head -1)
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

# One substitution per assignment: an assignment takes only the last one's
# status, so a combined line would swallow an early resolution failure.
lane_k1=$(lane_key_for "${lane_parts[0]}")
lane_k2=$(lane_key_for "${lane_parts[2]}")
lane_k3=$(lane_key_for "${lane_parts[4]}")
lane_name="${lane_k1}${lane_parts[1]}${lane_k2}${lane_parts[3]}${lane_k3}"

# ── The comparison ──────────────────────────────────────────────────────────

if [ "$lane_name" != "$contract" ]; then
  fail "the lane composes $lane_name, which the app does not. The app composes the pinned $contract."
fi

echo "✓ release name: both sides compose $contract"
exit 0
