#!/usr/bin/env bash
# Prove the two bash gates still bite (#1597, #1611). A gate nobody has watched
# fail is not a gate: each check below is run against an input built to break
# it, and against the near misses that must stay green, so the pass is evidence
# and not just silence. Every case here should fail if a line of the check it
# covers is deleted; a case that passes either way is worse than no case.

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

passed=0
failures=0

expect() {
  local want="$1" name="$2"
  shift 2
  local out status
  set +e
  out=$("$@" 2>&1)
  status=$?
  set -e
  if [ "$status" = "$want" ]; then
    passed=$((passed + 1))
  else
    failures=$((failures + 1))
    printf '  ✗ %s: expected exit %s, got %s\n' "$name" "$want" "$status" >&2
    printf '%s\n' "$out" | sed 's/^/      /' >&2
  fi
}

# ── The link check ──────────────────────────────────────────────────────────

sandbox="$work/links"
mkdir -p "$sandbox/docs/deep"
cd "$sandbox"
git init -q -b main .
git config user.email "test@example.com"
git config user.name "Hygiene self-test"
git config commit.gpgsign false

printf '# Target\n' >docs/target.md
printf '# Spare\n' >docs/spare.md
printf '# Read me\n\nSee [the target](docs/target.md).\n' >README.md
printf 'See [what went](../nowhere-at-all.md).\n' >docs/stale.md
for i in $(seq 1 50); do printf 'line %s of prose.\n' "$i"; done >docs/long.md
git add -A
git commit -qm "base"

# A remote-tracking ref, so the checks that leave LINK_CHECK_BASE unset
# exercise the branch detection and the origin/main fallback rather than
# exiting early on an unresolvable base.
git update-ref refs/remotes/origin/main main
git checkout -qb branch

link_check() {
  LINK_CHECK_BASE=main bash "$repo_root/scripts/check-links.sh"
}

link_check_bare() {
  bash "$repo_root/scripts/check-links.sh"
}

write_page() {
  printf '%s\n' "$@" >docs/deep/page.md
  git add docs/deep/page.md
  git commit -qm "page" --allow-empty
}

write_page '# Page' 'See [the target](../target.md).'
expect 0 "a relative link resolved from the linking file's own directory" link_check

write_page '# Page' 'See [the target](/docs/target.md).'
expect 0 "a repo-root path" link_check

write_page '# Page' 'See [the target](../target.md#a-heading) and [this page](#local).'
expect 0 "fragments on a real file, and an anchor with no path" link_check

write_page '# Page' 'See [the site](https://example.invalid/nothing) and [mail](mailto:a@b.c).'
expect 0 "external URLs, which are somebody else's server" link_check

write_page '# Page' 'Wrapped prose that runs on for a while and then' 'carries [the target](../target.md) onto a second line.'
expect 0 "a valid link after a reflow" link_check

write_page '# Page' '```markdown' '[an example](docs/does-not-exist.md)' '```'
expect 0 "a dangling link inside a fenced code block" link_check

write_page '# Page' 'Inline `[an example](docs/does-not-exist.md)` in a code span.'
expect 0 "a dangling link inside an inline code span" link_check

write_page '# Page' 'See [the target](../gone.md).'
expect 1 "a dangling relative link" link_check

write_page '# Page' 'See [the target](/docs/gone.md).'
expect 1 "a dangling repo-root path" link_check

write_page '# Page' '![a diagram](../gone.png)'
expect 1 "a dangling image" link_check

write_page '# Page' 'See [the target][ref].' '' '[ref]: ../gone.md'
expect 1 "a dangling reference definition" link_check

write_page '# Page' 'See [the target](../gone.md).'
expect 1 "the base derived from the branch name rather than the environment" link_check_bare
expect 0 "the documented bypass, on the same state" env SKIP_LINK_CHECK=1 bash "$repo_root/scripts/check-links.sh"

# A link far down a file, after an earlier hunk: the only case that notices if
# the hunk-header arithmetic drifts by a line.
write_page '# Page' 'Nothing broken on this page.'
awk 'NR == 5 { print "line 5, edited."; next } { print }' docs/long.md >"$work/long" && mv "$work/long" docs/long.md
awk 'NR == 40 { print "See [the target](gone-from-here.md)." } { print }' docs/long.md >"$work/long" && mv "$work/long" docs/long.md
git add docs/long.md
git commit -qm "edit line 5 and add a link at line 40"
expect 1 "a dangling link 40 lines down, after an earlier hunk" link_check

git checkout -q main -- docs/long.md
git commit -qm "put the long file back"
expect 0 "the long file restored" link_check

# The working tree, not HEAD: a link is written before it is committed, and an
# uncommitted edit above one must not renumber what gets read.
printf 'See [the target](../gone.md).\n' >>docs/deep/page.md
expect 1 "a dangling link that is not committed yet" link_check
git checkout -q -- docs/deep/page.md
expect 0 "the same file once the link is taken out again" link_check

printf 'a new first line\nand another\nand a third\n' | cat - docs/stale.md >"$work/stale" && mv "$work/stale" docs/stale.md
git add docs/stale.md
git commit -qm "prepend three lines above an old dangling link"
expect 0 "lines added above a link that was already broken and was not touched" link_check
git checkout -q main -- docs/stale.md
expect 0 "those lines taken out again in the working tree" link_check
git checkout -q HEAD -- docs/stale.md

# Files the branch removes, which the changed-lines half cannot see.
git rm -q docs/spare.md
git commit -qm "remove a file nothing links to"
expect 0 "removing a file no link points at" link_check

git mv docs/target.md docs/renamed.md
git commit -qm "rename the linked file"
expect 1 "a rename that leaves an untouched file pointing at the old path" link_check

git mv docs/renamed.md docs/target.md
git commit -qm "put the name back"
expect 0 "the rename undone" link_check

# Where the check runs at all: on main it does not, on a branch cut from the
# same commit it does, and on a detached HEAD it cannot tell, so it does not.
git checkout -q main
printf '\nAnd [what went](docs/vanished.md).\n' >>README.md
git add README.md
git commit -qm "a dangling link on main"
expect 0 "a dangling link on main, which this gate does not police" link_check_bare
git checkout -qb sidebranch
expect 1 "the same commit on a branch, which it does" link_check_bare
git checkout -q --detach
expect 0 "a detached HEAD, where there is no branch to derive a base from" link_check_bare

cd "$repo_root"

# ── The release name check ──────────────────────────────────────────────────

swift_fixture() {
  cat >"$1" <<EOF
enum SentryRelease {
  static func name(bundleId: String?, shortVersion: String?, buildNumber: String?) -> String? {
    guard let bundleId, let shortVersion, let buildNumber else { return nil }
    return "\\(bundleId)$2\\(shortVersion)$3\\(buildNumber)"
  }

  static func name(for bundle: Bundle) -> String? {
    name(
      bundleId: bundle.bundleIdentifier,
      shortVersion: bundle.object(forInfoDictionaryKey: "$4") as? String,
      buildNumber: bundle.object(forInfoDictionaryKey: "$5") as? String)
  }
}
EOF
}

lane_fixture() {
  cat >"$1" <<EOF
      - name: Create the Sentry release for this build
        run: |
          key() { /usr/libexec/PlistBuddy -c "Print :\$1" "\$plist"; }
          identifier="\$(key CFBundleIdentifier)"
          short_version="\$(key $4)"
          build_number="\$(key $5)"
          release="\$identifier$2\$short_version$3\$build_number"
          echo "Sentry release: \$release"
EOF
}

release_check() {
  RELEASE_NAME_SWIFT="$1" RELEASE_NAME_WORKFLOW="$2" \
    bash "$repo_root/scripts/check-release-name.sh"
}

good_swift="$work/Good.swift"
good_lane="$work/good-lane.yml"
swift_fixture "$good_swift" "@" "+" CFBundleShortVersionString CFBundleVersion
lane_fixture "$good_lane" "@" "+" CFBundleShortVersionString CFBundleVersion
expect 0 "two sides that agree" release_check "$good_swift" "$good_lane"

swapped_swift="$work/Swapped.swift"
swift_fixture "$swapped_swift" "+" "@" CFBundleShortVersionString CFBundleVersion
expect 1 "the app swapping its separators" release_check "$swapped_swift" "$good_lane"

swapped_lane="$work/swapped-lane.yml"
lane_fixture "$swapped_lane" "+" "@" CFBundleShortVersionString CFBundleVersion
expect 1 "the lane swapping its separators" release_check "$good_swift" "$swapped_lane"

expect 1 "both sides agreeing on a format that is not the contract" \
  release_check "$swapped_swift" "$swapped_lane"

reordered_lane="$work/reordered-lane.yml"
lane_fixture "$reordered_lane" "@" "+" CFBundleVersion CFBundleShortVersionString
expect 1 "the lane reading the version fields in the other order" release_check "$good_swift" "$reordered_lane"

wrong_field_swift="$work/WrongField.swift"
swift_fixture "$wrong_field_swift" "@" "+" CFBundleShortVersionString CFBundleName
expect 1 "the app reading a field that is not in the contract" release_check "$wrong_field_swift" "$good_lane"

reflowed_swift="$work/Reflowed.swift"
cat >"$reflowed_swift" <<'EOF'
enum SentryRelease {
  // A reformat: the arguments wrap differently and a comment sits in the middle.
  static func name(
    bundleId: String?,
    shortVersion: String?,
    buildNumber: String?
  ) -> String? {
    guard let bundleId, let shortVersion, let buildNumber else { return nil }
    return "\(bundleId)@\(shortVersion)+\(buildNumber)"
  }

  static func name(for bundle: Bundle) -> String? {
    name(
      bundleId: bundle.bundleIdentifier,
      shortVersion: bundle.object(
        forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
      buildNumber: bundle.object(
        forInfoDictionaryKey: "CFBundleVersion") as? String)
  }
}
EOF
expect 0 "the app after a reformat" release_check "$reflowed_swift" "$good_lane"

hoisted_swift="$work/Hoisted.swift"
cat >"$hoisted_swift" <<'EOF'
enum SentryRelease {
  static func name(bundleId: String?, shortVersion: String?, buildNumber: String?) -> String? {
    guard let bundleId, let shortVersion, let buildNumber else { return nil }
    return "\(bundleId)@\(shortVersion)+\(buildNumber)"
  }

  static func name(for bundle: Bundle) -> String? {
    let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    return name(bundleId: bundle.bundleIdentifier, shortVersion: short, buildNumber: build)
  }
}
EOF
expect 0 "the app after hoisting the plist reads into locals" release_check "$hoisted_swift" "$good_lane"

renamed_vars_lane="$work/renamed-vars-lane.yml"
cat >"$renamed_vars_lane" <<'EOF'
      - name: Create the Sentry release for this build
        run: |
              key() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
              app_id="$(key CFBundleIdentifier)"
              marketing="$(key CFBundleShortVersionString)"
              build="$(key CFBundleVersion)"
              release="${app_id}@${marketing}+${build}"
              echo "created $release"
EOF
expect 0 "the lane after renaming its shell variables and reindenting" \
  release_check "$good_swift" "$renamed_vars_lane"

second_mention_lane="$work/second-mention-lane.yml"
cat >"$second_mention_lane" <<'EOF'
      - name: Create the Sentry release for this build
        run: |
          key() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
          identifier="$(key CFBundleIdentifier)"
          short_version="$(key CFBundleShortVersionString)"
          build_number="$(key CFBundleVersion)"
          release="$identifier@$short_version+$build_number"
          sentry-cli releases finalize "$release" && note_release="$release"
EOF
expect 0 "the lane mentioning the release again further down" \
  release_check "$good_swift" "$second_mention_lane"

expect 0 "the files this repo actually ships" bash "$repo_root/scripts/check-release-name.sh"

# ── Result ──────────────────────────────────────────────────────────────────

if [ "$failures" -gt 0 ]; then
  printf '\n✗ hygiene self-test: %s of %s cases failed\n' "$failures" "$((passed + failures))" >&2
  exit 1
fi

printf '✓ hygiene self-test: %s cases, both gates seen to fail and to pass\n' "$passed"
