# Testing the native iOS app on the simulator

How to build, run, snapshot-test, and UI-test the native SwiftUI app
(`ios/`) on the iOS Simulator — including the tooling an AI agent uses to
do it, and the host gotchas that waste the most time.

## The tooling

**The reliable, primary path is the Xcode CLI: `just` + `xcodebuild` + `xcrun
simctl`.** That's what builds, runs the simulator, takes screenshots, and runs
the tests below. Two MCP servers are *available* as conveniences, but neither is
required and the CLI is what you should reach for first.

### Xcode CLI (what to use)

Bindings are a build precondition (`ios/generated`, gitignored) — `just`
regenerates them only when the core changed.

```bash
# Simulator control + screenshots
UDID=$(xcrun simctl create snap "iPhone 16" "iOS26.5")
xcrun simctl boot "$UDID"
xcrun simctl install "$UDID" /path/to/Intrada.app
xcrun simctl launch "$UDID" com.intrada.native --seed-sample-data
xcrun simctl io "$UDID" screenshot shot.png      # ← how to screenshot the sim
```

### MCP servers (optional)

- **XcodeBuildMCP** — registered in `.mcp.json` (`npx xcodebuildmcp@latest`, runs
  on demand, no install beyond Node). It exposes MCP tools that wrap the same
  build/simulator/test/screenshot actions for an MCP client. Upstream:
  <https://github.com/cameroncooke/XcodeBuildMCP>. Available, but the CLI above
  is the path of record.
- **Xcode-app driver** (`mcp__xcode__*`: `XcodeListWindows`, `GetTestList`,
  `RunSomeTests`, `GetBuildLog`, …) automates an *open* Xcode window. Configured
  per-developer (not in this repo). Fallback only — GUI builds hit
  unresolved-SwiftPM-package and code-signing errors that the CLI's
  `CODE_SIGNING_ALLOWED=NO` avoids.

### `just` recipes

```bash
just ios            # regen bindings if core changed → xcodegen → open Xcode
just ios-run        # regen → xcodegen → build + launch on sim + screenshot (SEED=1)
SEED=0 just ios-run # …against your real on-device data, not the demo seed
just ios-gen        # force-regenerate the Swift bindings (after a core change)
just ios-snapshots-optimize   # oxipng -o max every reference (run before commit)
just ios-snapshots-check      # orphan + 200 KB-ceiling guard (same as CI)
just ios-test                 # fast tier: IntradaTests only (unit + snapshot) on a per-worktree sim
just ios-test-full            # full gate: + IntradaUITests — what ship/CI run before merge (CI parity)
just ios-test-sim-clean       # delete this worktree's ios-test sim
```

## Snapshot tests (the per-PR UI regression gate)

References live in `ios/IntradaTests/__Snapshots__/**` and are recorded on
**iPhone 16 / iOS 26.5** to match CI (renderer-specific — see
`.github/workflows/ci.yml` and `.claude/rules/ios-quality.md`).

```bash
# Create the CI-matching simulator
UDID=$(xcrun simctl create snap "iPhone 16" "iOS26.5")

# Run / record (a missing reference auto-records and "fails" the first run)
xcodebuild test -project ios/Intrada.xcodeproj -scheme Intrada -sdk iphonesimulator \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO \
  -only-testing:IntradaTests/ScreenSnapshotTests/testLibraryScreen

# After recording: optimise (drops Xcode's opaque alpha, ~75% smaller) and re-run
just ios-snapshots-optimize
```

Re-record after any intentional UI change; delete a test → delete its PNG
(orphans fail CI). Optimise before committing or the Snapshot Hygiene job fails.

## UI tests (gesture / interaction — what snapshots can't cover)

`ios/IntradaUITests/` drives the *running* app (e.g. type in search → assert the
list filters). Launch args seed deterministic data:

```bash
xcodebuild test -project ios/Intrada.xcodeproj -scheme Intrada -sdk iphonesimulator \
  -destination "id=$UDID" CODE_SIGNING_ALLOWED=NO \
  -only-testing:IntradaUITests
```

The app seeds the 6-item demo set when launched with `--seed-sample-data`
(`XCUIApplication().launchArguments = ["--seed-sample-data"]`). Use a UI test —
not a snapshot — to prove an *interaction* works; a snapshot can't catch that a
gesture (e.g. pull-to-reveal) never fired.

## Host gotchas (these eat hours)

- **Quit Xcode before `xcodebuild test`.** A persistent
  `Pseudo Terminal Setup Error / Device not configured` ("Failed to install or
  launch the test runner") is almost always Xcode.app holding the simulator
  while the CLI also wants it. `osascript -e 'quit app "Xcode"'`, then re-run.
- **Transient runner flake** → restart the sim service:
  `killall com.apple.CoreSimulator.CoreSimulatorService Simulator`, then re-boot
  the sim. UI-test *runners* trip this first; if unit tests pass but the UI test
  fails on launch, it's the host, not the test.
- **Stale bindings after pulling/rebasing** onto a main with core changes →
  `extra argument` / `cannot find type` Swift errors. Run `just ios-gen`
  (see CLAUDE.md → Native iOS Shell, and the memory note on rebase+regen).
- **Clean up** the throwaway sims you create: `xcrun simctl delete <udid>`
  (or `just ios-test-sim-clean` for the sim `just ios-test` made in this worktree).
- **Silence is success on the `just` path.** `_ios-test-without-building` passes
  `-quiet`, so a passing run prints a handful of lines and no test counts. The
  recipe now prints `✓ N passed, M failed, K skipped` at the end, and fails if
  the bundle reports zero passed, so trust that line rather than the length of
  the log (#1536).
- **`IDERunDestination: Supported platforms ... is empty` is noise.** It prints
  on every run, green ones included. The recipes pin `-destination "id=$udid"`,
  so it never means a destination failed to resolve.
- **Counts live in the result bundle**, not the console:
  `xcrun xcresulttool get test-results summary --path ios/build/dd/Logs/Test/Test-Intrada-*.xcresult`.
- **Driving `xcodebuild test` yourself needs `CODE_SIGNING_ALLOWED=NO`.** The
  test bundles carry no `Info.plist` settings, so without it both test targets
  fail to sign before anything compiles. Both recipe steps pass it (#1537).

## Running alongside another checkout (worktrees)

Git worktrees and the main checkout are **isolated on disk** — separate working
trees, DerivedData (keyed by project *path*), `ios/generated` bindings, cargo
`target/`, and snapshot PNG files. Building or recording in one never overwrites the
other's files.

**`just worktree-new <name>`** creates a worktree at
`$INTRADA_WORKTREE_ROOT/<name>` (also `<name>`'s branch — no slashes, so
the worktree root stays flat and the sim-name collision check below
actually sees every worktree). `INTRADA_WORKTREE_ROOT` defaults to
`../intrada-worktrees` (sibling to the main checkout) when unset. Runs
off fresh `origin/main` and seeds it from the main
checkout's warm caches (`target/`, `ios/build/spm`, `ios/build/dd`,
`ios/generated`) via APFS clonefile (`cp -Rc`, copy-on-write — near-instant,
no duplicated disk until the copies diverge). Cuts the first `just check` /
`just ios-test` in a fresh worktree from ~5-10 minutes cold to close to what
the main checkout pays warm. `ios/generated` seeds only when the new
worktree's own core source hash matches the main checkout's binding stamp
(same rule `_ios-sync` enforces) — otherwise it's left to regenerate.
Refuses a `<name>` that sanitises to the same simulator name as an existing
worktree (the `foo`/`foo.1` collision below). `just worktree-rm <name>`
cleans up the worktree's sim, then removes the worktree.

**The simulator is the exception.** The iOS Simulator and
`CoreSimulatorService` are **one per macOS login, shared across every checkout**.
That's the only real clash surface, and the recovery commands above are global
sledgehammers — `killall com.apple.CoreSimulator.CoreSimulatorService`,
`simctl shutdown all`, `simctl erase|delete` will **kill or wipe a sim another
checkout is using**.

Rules to keep two checkouts from colliding:

- **Test runs serialise on app launch, whatever device they name** (#1621).
  Each worktree's `just ios-test`/`ios-test-full` boots its own sim
  (`intrada-test-26-5-<worktree-basename>`), so there is no device clash
  between worktrees (two worktree dirs that sanitise to the same name, e.g.
  `foo.1` and `foo-1`, would share a sim; slug-like worktree names avoid this),
  and the device model makes no difference to snapshot output
  (swift-snapshot-testing pins `.iPhone13`; only the iOS 26.5 runtime affects
  the pixels). None of that stops CoreSimulatorService and SpringBoard
  contending when two runs launch an app at the same moment. Measured on
  2026-09-10, an M5 Pro with 18 cores and 48 GB, two worktrees each on its own
  simulator with its own DerivedData: one worktree passed 389 tests in 42
  seconds while the other failed at launch nine times with
  `Busy ("Application failed preflight checks")`; the worktree that failed,
  run alone thirty seconds later, passed 371 tests in 22 seconds with no Busy
  lines at all (a different suite from the 389-test run, so the 22 versus 42
  seconds is indicative, not an exact delta). Same failure surface as #1480.
  A fast-tier run is well under a minute either way, so run test suites one
  after another rather than planning around concurrent test launches; the
  isolation above is real for editing and building, not for test launch.
  `just ios-test-sim-clean` deletes only the current worktree's sim.
- **Two overlapping runs in the *same* checkout are not safe** (#1192) — they'd
  share that checkout's simulator and DerivedData and crash each other's
  XCUITests. The recipes refuse to start when another `xcodebuild`/
  `XCTestAgent` is already live against this checkout, and they also warn (not
  block) if `crates/` has uncommitted changes, since a concurrent core edit
  can red the gate with a compile error unrelated to the diff under test.
- **Ad-hoc `xcodebuild` / `simctl` sessions that share one device still
  serialize.** If you run the raw `xcodebuild test` snippets above (not via
  `just ios-test`), give each session a **worktree-scoped sim** targeted by
  UDID, instead of a bare `"iPhone 16"` both checkouts might grab:
  ```bash
  UDID=$(xcrun simctl create "snap-$(basename "$PWD")" "iPhone 16" "iOS26.5")
  ```
  Two sessions pointed at the *same* device produce the pty contention errors
  above; distinct devices avoid that specific clash, but still serialise on
  app launch for the reason above.
- **Only touch sims you created.** Delete *your* UDID (or `just
  ios-test-sim-clean` for the recipe's sim) when done; never `shutdown all` /
  `delete unavailable` / restart `CoreSimulatorService` blind.
- **A sim that has failed a launch can then fail snapshots that have nothing
  to do with your diff.** After a `Busy ("Application failed preflight
  checks")` launch error under host load, this worktree's sim went on to red
  four unrelated snapshot tests, deterministically, with content identical to
  the reference and only text metrics moved (#1480). A fresh device passed the
  same build. Before believing a snapshot failure you can't explain, run it on
  a new sim: `just ios-test-sim-clean` then re-run, or create a scratch UDID
  as above.
- **Check before any global op or a fresh test run** whether another session is
  live:
  ```bash
  xcrun simctl list devices | grep Booted     # sims someone may be using
  pgrep -fl 'xcodebuild|XCTestAgent'           # a build/test already running
  pgrep -x Xcode                               # Xcode open (may hold a sim)
  ```
  If any of those show activity you didn't start, **stop and ask** before
  resetting the sim service or shutting sims down — assume it's the other
  checkout's. (For agents: this is a hard rule — see CLAUDE.md → Native iOS.)

## CI

`.github/workflows/ci.yml` builds the app once in **Native iOS: build** on a
pinned `macos-26` / Xcode 26.5 runner (clean host, no pty contention), then runs
**Native iOS: unit + snapshot** and the two **Native iOS: UI** slices
(`builder`, `rest`) against the test products that job uploads, with
**Native iOS (build + test)** as the fan-in required check. The build job runs
`_ios-build-for-testing` and each test job runs `_ios-test-without-building`
against the artifact's `.xctestrun`, the same recipes local dev's full gate uses
(#1198, #1207), so the CI and local invocations cannot drift apart, and
**Snapshot Hygiene** runs alongside. The Release compile guard (`#if DEBUG`
divergence, #1177) runs on pushes to main only, not on this path (#1651). The
job shape, the measurements behind it and the cache rules are written up in
[`reference.md`](reference.md#why-the-native-ios-ci-is-shaped-the-way-it-is-2026-09-03).
If snapshots/UI tests are green there, the local pty errors above were host-only.
