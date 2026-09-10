# Operational reference

> The detail behind the rules in [`CLAUDE.md`](../CLAUDE.md). That file says
> *what* to do and stays short because it loads into every session; this one says
> *how* and *why*, and is read on demand.
>
> Last reviewed: 2026-08-14.

## Commands

```bash
just check                 # fmt-check → lint → test → hygiene; mirrors CI
just test                  # nextest, same as CI's `test` job
just lint                  # clippy -D warnings, same targets as CI's `clippy` job
just hygiene               # typos, cargo-shear, actionlint, links, release name, self-tests
just pr-visuals            # before/after markdown for snapshot references this branch changed
cargo test -p intrada-api  # API tests only
just ios-fmt               # format Swift sources in place (swift format)
just ios-fmt-check         # Swift formatting gate (CI runs this too)
just ios                   # regen bindings (if core changed) + open Xcode
just ios-gen               # force a full binding regenerate
just ios-run               # build + launch on simulator + screenshot
just ios-logs              # stream booted-sim logs, filtered to our subsystem
just ios-test              # unit + snapshot (fast inner-loop tier)
just ios-test-full         # adds XCUITests (the merge gate; mirrors CI)
just ios-snapshots-check   # fail orphaned / oversized snapshot references
just ios-snapshots-optimize # drop Xcode's opaque alpha channel (~75% smaller)
just check-all             # check + the fast ios-test tier
just testflight            # signed Release .ipa → TestFlight (needs setup)
just worktree-new <name>   # new worktree, seeded from the main checkout's warm caches
just worktree-rm <name>    # clean up a worktree's sim, then remove it
```

Test tiering, worktree simulator isolation, and the green-stamp skip (which lets
a recipe no-op when HEAD is already stamped green at that tier) are documented in
[`ios-testing.md`](ios-testing.md).

### Binding regeneration

`just ios` and `just ios-run` auto-regenerate the Swift bindings only when
`intrada-core` or `intrada-ffi` changed (a `ios/generated/.gen-stamp` hash), so
they stay in sync without slowing pure-Swift edits. `just ios-gen` forces a full
regenerate. A stale `.gen-stamp` is the tell when iOS tests behave oddly after a
core type change.

### Swift formatting

`just ios-fmt-check` covers the hand-written trees (`ios/Intrada`,
`ios/IntradaTests`, `ios/IntradaUITests`) with the toolchain-bundled
`swift format` on default config. `ios/generated` is excluded — generated
bindings are never hand-edited. The one-time whole-tree reformat commit is listed
in `.git-blame-ignore-revs`; run this once so `git blame` skips it:

```bash
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

### Logging

`just ios-logs` filters the unified log to `subsystem == "com.intrada.native"`,
cutting the simulator's UIKit/keyboard/gesture noise so first-party signal is
visible. `report(_:)` (`ios/Intrada/Core/Logging.swift`) logs swallowed FFI and
bincode bridge errors there. That is the silent-no-op class (#846), which
otherwise leaves no trace anywhere Sentry has no DSN: CI always, and dev unless
`SENTRY_DSN_NATIVE` is set.

### TestFlight

`just testflight` builds a signed Release `.ipa` and uploads it to TestFlight
(internal testing), mirroring `.github/workflows/release-testflight.yml` (which
runs on `workflow_dispatch` or a `v*` tag, never per-PR). Signing is fastlane
**match**, and it needs Ruby >= 3 — system Ruby 2.6 is too old, use `rbenv` —
plus a one-time App Store Connect and match bootstrap. Full setup and decisions:
[`../specs/ios-testflight-cicd.md`](../specs/ios-testflight-cicd.md) and
SETUP.md §4a.

A tagged run also bakes `SENTRY_DSN_NATIVE` into the build and, after the
upload, creates the matching Sentry release in `intrada-mobile`, so a beta
crash resolves to a build and a commit. The name comes off the uploaded `.ipa`
and matches what `SentryRelease.swift` reports at runtime. Miss the DSN secret
and the lane fails at the trigger rather than shipping a build that reports
nothing (#1553); the symbols themselves are still not uploaded (#1610).

### Git hooks

Git hooks install automatically for Claude Code sessions (a `SessionStart` hook
runs `scripts/install-git-hooks.sh`). They catch the "pushed onto a merged-PR
branch and the commits orphaned" pitfall via a pre-push check against `gh`, and
flag comment-bloat. Manual install, forking setup, and first-time iOS setup are
in the [README](../README.md#prerequisites) — read that before your first
`just ios`.

### Demo data vs real on-device data

A plain launch (`just ios` then Cmd+R on the default **Intrada** scheme, or any
build with no launch args) runs **local-first**: the Library hydrates from the
on-device GRDB store, so items you add survive restarts.

The 6 sample pieces are **opt-in** via the `--seed-sample-data` launch arg. In
Xcode, pick the **Intrada (Seeded)** scheme from the scheme dropdown (defined in
`ios/project.yml`) and Cmd+R; the selection persists across `just ios`
regenerations. `just ios-run` passes the same arg by default (`SEED=1`); use
`SEED=0 just ios-run` to launch against your real data.

Seed mode (`Event::LoadSampleData`) replaces the model with demo items and
**skips store hydration**, so don't use it when testing persistence. Your saved
rows are still on disk but won't be read back.

## Knowledge graph (graphify)

The graph lives in the **main checkout** at `graphify-out/` (gitignored, so
worktrees don't carry it). Find the main checkout from any worktree via
`git rev-parse --path-format=absolute --git-common-dir`, then take its parent.

Scope is controlled by the committed `.graphifyignore`: vendored and minified JS,
`specs/_archive/`, `.specify/`, and generated schemas are excluded.

```bash
graphify query "<question>"   # from the main checkout root
graphify path A B             # trace how two concepts connect
graphify . --update           # refresh after a doc-heavy merge
```

The post-commit and post-checkout hooks in the main checkout do free AST-only
code refreshes automatically. Run `graphify . --update` manually after doc-heavy
merges (specs/, docs/, CLAUDE.md); it is incremental and content-hash cached, so
it costs a small fraction of a full build.

## Environment variables

### API (intrada-api)

`TURSO_DATABASE_URL`, `TURSO_AUTH_TOKEN` (required), `CLERK_ISSUER_URL` (required
in prod), `ALLOWED_ORIGIN` (see SETUP.md §2), `PORT` (default 3001).

### Native iOS build (compile-time)

`CLERK_PUBLISHABLE_KEY`, `INTRADA_API_URL` (default
`https://intrada-api.fly.dev`).

### Native iOS (optional): Sentry

`SENTRY_DSN_NATIVE` in `.env` captures crash and error events from local dev
builds, tagged `environment=development`. The plumbing is fiddly and was silently
broken once, so the whole chain is worth stating:

1. `xcodegen` writes the value to the `SENTRY_DSN` build setting.
2. The target's partial `Info.plist` (`ios/Intrada/Info.plist`) carries
   `SENTRY_DSN = $(SENTRY_DSN)` so the value lands in the built plist.
3. The justfile's `set dotenv-load` feeds the var in.

Step 2 is the non-obvious one: a custom key **cannot** ride `INFOPLIST_KEY_*`,
which `GENERATE_INFOPLIST_FILE` only honours for Apple-recognised keys. That gap
meant Sentry silently never started.

It is **unset in CI**, so test and smoke runs send nothing. The app only starts
Sentry on a real `https://` DSN, so an empty or unexpanded value is a safe no-op.

## Gotchas, in full

### JSON-only serde attrs break the Crux bincode FFI bridge

The native iOS shell exchanges `Event` / `Effect` / `ViewModel` with the core as
**positional bincode**, a non-self-describing format. serde attributes that only
make sense for a self-describing format (JSON) silently corrupt that wire: the
Swift side serializes every field and level by structure, but a JSON-oriented
deserializer reads a different shape, **misaligns the byte stream, and the whole
event fails to decode**. `Store.send` swallows the bridge error via `guarded`, so
the symptom is a silent no-op — "editing doesn't save" (#846) — not a crash.

The specific offender we hit was `#[serde(deserialize_with = "double_option")]`
on `UpdateItem`'s three-state `Option<Option<T>>` fields. `double_option` reads a
single option level, which is right for JSON (a present key is one `Option<T>`,
and `null` means clear), but bincode needs both levels.

The fix: make such helpers **format-aware** via
`Deserializer::is_human_readable()`, with a JSON branch and a bincode branch, so
the same type round-trips on both wires.

Rules of thumb for any type crossing the bridge (`Event`, `Effect`, `ViewModel`,
and everything they contain):

- Be wary of `deserialize_with` / `serialize_with`, and of `skip_serializing_if`
  combined with non-trailing fields — anything assuming "absent" versus "present"
  semantics. bincode has no "absent".
- **Stub-bridge tests can't catch this.** Cover bridge-crossing types with a
  *real*-bridge round-trip (`LiveBridge` in `StoreEffectLoopTests`) that drives
  the actual Swift↔Rust bincode serialization. See
  `testRealBridgeEditAppliesToViewModel`.

### `option_env!` needs `cargo:rerun-if-env-changed`

If a build script — or an `option_env!` site indirectly, via macro expansion —
reads an env var, pair it with `println!("cargo:rerun-if-env-changed=NAME")` in
`build.rs`. Without it, cargo caches the macro expansion across builds and your
"I changed the env var" rebuild silently uses stale values. We have hit this on
`CLERK_PUBLISHABLE_KEY` and `INTRADA_API_URL`.

## Why agent teams were retired (#1223)

In-session agent teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`,
`/team-vertical`) were tried on #1223 and retired. On a slice coupled by a bridge
contract, the split cost more than it bought. Measured on that PR:

- **The halves were never independent.** One genuinely parallel window of about
  25 minutes, against roughly 20 coordination messages, three nudges to idle
  teammates, and three replies to superseded instructions.
- **The split caused the worst bug in the PR.** The shell teammate restarted the
  click without bumping `pulse_seq`, because it could not see the core invariant
  that says a restart is signalled by that field. It then rebuilt the hardest
  code in the slice from scratch. One agent holding both sides would not have
  written it.
- **The quality came from elsewhere**: adversarial review, the pre-push comment
  hook, and mutation-testing vacuous tests. All three work with one agent.

The rule that came out of it, one agent per vertical slice and fan out only on
genuinely independent work, is in `.claude/skills/intrada-parallel-streams/SKILL.md`.

## Where #1256 Phase B's time actually went (2026-08-07)

A retrospective measured rather than estimated, after Phase B felt slow. It is
the source of the split-the-phase rule, the wire-shape gate, the shared fixtures
and `just ios-snapshots-record`.

**The tooling was not the bottleneck.** Timed on the worktree that built it:

| Loop | Wall clock |
|------|-----------|
| `just ios-test`, warm | 43s |
| `just ios-test` after one Swift edit | 31s |
| One scoped test via `_ios-test-without-building` | 24s |
| Whole CI run | ~10 min |

Roughly, across about two hours: writing code and tests ~55%, review-and-then-
re-run-everything ~20%, local gates ~15%, flakes and dead ends ~10%.

**What actually cost time, in order:**

1. **One PR for a phase spanning core and screens.** 4,300 insertions, seven
   designed frames, a bridge change and a migration. Both self-review blockers
   were in core code written in the first third; finding them at the end meant
   re-running every gate and rebasing onto a main that had moved.
2. **Reviewing once, at the end.** `requesting-code-review` says "review early,
   often". A review after the core landed would have caught both blockers before
   any SwiftUI existed.
3. **The field-addition tax.** Adding `origin` to `BlockSpec`/`BlockRecord` broke
   six construction sites, each found by a separate build, because errors were
   read one at a time rather than with `cargo check --all-targets`.
4. **Snapshot recording by hand.** Delete, run, run, optimise, check — five
   steps, done five times. `ios-snapshots-optimize` over the whole suite cost
   more than the test run it followed (94s → 50s once scoped).
5. **Fighting the size ceiling before reading it.** Four cycles trying crops on
   gradient-heavy references, when `check-snapshots.sh`'s own comment says
   cropping cannot help those.

**Tests, judged honestly.** Duration is fine. One real flake —
`ClickEngineTests` stands up an `AVAudioEngine` inside a merge gate (#1282).
The simulator's own "Busy / preflight checks" cost four local cycles. And the
criterion parser's fourteen green unit tests all used sentences written to match
the scanner, which is why it shipped misreading the likeliest real one.

**What was worth keeping**: the code-reviewer subagent (two blockers for
fourteen minutes), driving the simulator rather than trusting green tests, TDD
on the core, and reading the spec and mockups properly.

## Why the native iOS CI is shaped the way it is (2026-09-03)

The native iOS gate fans out (#1207): **Native iOS: build** compiles once and
uploads the built test products, the test jobs run against that artifact, and the
fan-in job **Native iOS (build + test)** stays the required status check. Timed
across three pull-request runs that touched the app, the critical path was
**Path Changes** (10s), then the build job (339-451s), then **Native iOS: UI**
(702-739s): roughly 19 to 20 minutes of wall clock. Inside the build job,
regenerating bindings cost 54s (only when the core changed),
`build-for-testing` 86s, toolchain and cache setup about 90s, and the Release
compile guard 155-197s.

The run that landed the changes below came in at **11m26s** end to end: build
162s, then the longer UI slice at 495s. One number to keep in mind before
slicing the UI suite again: the two slices took 436s for three tests and 495s
for four, so the cost is per test rather than per class, and a further split
keeps paying until the per-test stall itself is fixed (#947).

What those numbers changed:

- **The Release guard runs beside the tests, not in front of them.** The
  `#if DEBUG` divergence check (#1177) was 155-197s of that critical path and
  nothing downstream reads what it produces, so it moved to a sibling job,
  `native-ios-build-release`, which starts when the build job finishes and runs
  concurrently with the two test jobs. It keeps its own DerivedData cache
  (`ios-dd-release-v1-*`) and is listed in the fan-in gate, so a Release-only
  break still fails the required check. This is the trade #1207 parked in
  2026-08 until "the full tier's wall time grows past ~10 minutes", which 19
  to 20 minutes clears: the price paid is more concurrent macOS jobs (four
  rather than two, billed at 10x) and the artifact downloaded by each test
  job, in exchange for the wall clock.
- **The test jobs stopped generating the Xcode project.** Both now run
  `xcodebuild test-without-building -xctestrun <path>` against the `.xctestrun`
  inside the downloaded `native-ios-test-products` artifact. That file is
  self-describing: it names the test bundles, the host app and the environment
  to launch them in, so running the tests needs no `.xcodeproj` and no scheme.
  Dropping project generation takes xcodegen, the `ios/generated` bindings
  restore and the 928 MB SwiftPM cache out of both jobs, and with no project to
  open there is no package graph to resolve, so nothing can re-clone the
  dependencies over the network (the #813 flake that restore guarded against).
- **The UI suite runs as two sliced jobs.** Seven XCUITests across four
  classes were taking 653-692s serially, the longest single step in the
  pipeline, and `SessionBuilderUITests` is over a third of that on its own
  (#947). **Native iOS: UI** is now a two-entry matrix: one slice runs that
  class, the other runs its complement, expressed as `-skip-testing:` so a UI
  class added later joins the second slice rather than silently running
  nowhere (the #1456 failure mode). xcodebuild's own parallel testing was
  tried first and rejected: it clones the destination simulator, and the
  clone's test runner failed to launch with "Application failed preflight
  checks (Busy)" under memory pressure, which reds the gate for no test
  reason. Slicing does not explain the idle stalls in the suite, which stay
  open as #947.
- **The Actions cache was over its ceiling.** The repo held 10.69 GB across 48
  entries against GitHub's 10 GB per-repo LRU limit, so entries were being
  evicted while runs still wanted them, which is the suspected cause of the
  unit + snapshot job's 225-509s spread. `ios-dd-*` accounted for 19 entries and
  4.36 GB, `ios-spm-*` for 3 entries and 2.79 GB (928 MB each), because caches
  are written per ref and every pull-request branch was saving its own copy. A
  scheduled **Cache Prune** workflow (`.github/workflows/cache-prune.yml`) now
  keeps the newest few entries per key family, and the iOS build caches restore
  on every ref but save only on main.
- **`save-if` is not an `actions/cache` input.** The DerivedData step had
  carried `save-if: ${{ github.ref == 'refs/heads/main' }}` and a comment
  saying "only main writes the cache" for months; an unknown input is silently
  ignored, so main-only writing never happened, which is how 19 `ios-dd-*`
  entries against six different refs accumulated. Proof after the fact:
  `refs/pull/1521/merge` wrote an `ios-dd-v2-*` entry on 2026-09-04 with that
  line in place. The mechanism that does work is
  `actions/cache/restore@v6` plus a separate `actions/cache/save@v6` step
  gated by `if: github.ref == 'refs/heads/main'`. `save-if` **is** a real
  rust-cache input, which is what made the mistake easy to keep: the same
  spelling means something in one action and nothing in the other. Check a
  cache rule by listing the refs that wrote its entries, never by reading the
  workflow.
- **Clippy had been asking for a cache nothing ever wrote.** rust-cache composes
  its key as `<prefix-key>-<job-name>-<arch>-…`, so `prefix-key: native` with
  `save-if: "false"` looked for `native-clippy-…` while the only entries in the
  repo were `native-test-Linux-x64-…` from **Test** and
  `native-ios-native-ios-build-Darwin-arm64-…` from the iOS build. It
  cold-compiled the workspace on every run. It now uses `prefix-key: clippy`,
  saving on main only, so pull requests restore main's copy. The general point:
  a rust-cache key carries the job name, so a `save-if: false` reader can only
  share with the *same* job on another ref, never with a different job.

## The self-hosted iOS runner (2026-09-10, #1577)

The iOS gate runs on a dedicated Mac for every same-repo push and pull request.
Fork pull requests keep the four rented `macos-26` jobs, which is what stops
untrusted code reaching the machine; #1636 covers proving that path still works.

**The machine.** A MacBook Pro M4, 10 cores, 24GB, reachable on the home network
as `Jons-MacBook-Pro-2.local`. Registered as repo runner `intrada-m4` with
labels `self-hosted, macOS, ARM64, intrada-m4`. It runs lid-closed on the
charger with idle sleep off.

**Why a login is needed after a reboot.** The runner is a launchd user agent, not
a daemon, because xcodebuild and the simulator need a real graphical session.
FileVault stays on, so automatic login is not available, and nothing runs until
someone logs in at the keyboard. Planned restarts go through
`sudo fdesetup authrestart`, which gets past the disk unlock but still leaves
the login window.

**Restarting it.**

```bash
cd ~/actions-runner && ./svc.sh status    # or stop / start
```

**Its toolchain is local, not installed per run.** Xcode with the iOS 26.5
simulator runtime, `just`, XcodeGen 2.46.0, `cargo-swift` 0.9.0 and Rust pinned
by the workflow through `RUSTUP_TOOLCHAIN`. XcodeGen lives in `~/.local/bin`,
which the runner finds through the `.path` file in its own directory, not
through a shell profile.

**It is single tenant.** The justfile derives the simulator device name from the
checkout folder name, and both a local clone and the runner's workspace reduce
to `intrada`, so both would fight over one device. Do no local iOS work on that
machine while it is a runner.

**When it is offline, same-repo CI queues rather than failing.** GitHub has no
automatic fall back to a rented runner, so a job waits for a runner that matches
its labels. If the gate is not starting, check the runner is online before
looking at the workflow.

**The workspace is deliberately kept warm** between runs, which is where most of
the speed comes from, so three things the rented runners got for free by
starting empty are now done explicitly. The gate runs `git clean -ffd`, without
`-x`, because `_ios-inputs-fingerprint` hashes untracked filenames under `ios/`
and one stray file makes the test step refuse. It deletes the previous run's
result bundles, because the test recipe reports its counts from the newest
`.xcresult` and treats one that exists as one this run wrote. And it uninstalls
the app from the test device, because `SessionRecoveryUITests` asserts a resume
prompt that a leftover crash-recovery blob would satisfy on its own.
`runner-housekeeping.yml` takes the build logs weekly and leaves the caches.

**The toolchain is asserted, not installed per run.** The machine updates itself,
and both the snapshot renderer and `swift format`'s defaults move with Xcode, so
the gate fails when `xcodebuild -version` is not the `SELFHOSTED_XCODE` value in
`ci.yml`, or when the iOS 26.5 simulator runtime is missing. A Software Update
therefore reds the gate with a readable message instead of changing its verdict.

## The API image build stopped caching its layers (2026-09-04)

**API Docker Build** exported a buildkit layer cache to GitHub Actions
(`cache-to: type=gha,mode=max`). One run of it wrote 26 `buildkit-blob-*`
entries and 1.96 GB, a fifth of the repo's 10 GB allowance, for a lane that
only runs when the API changes and is on hold behind the iOS pivot. Neither
mode was worth that:

- `mode=max` caches every intermediate layer, which is what made it 1.96 GB.
- `mode=min` caches only what the final image exports, and the `Dockerfile` is
  a cargo-chef build whose expensive layer (`cargo chef cook --release`) lives
  in the `builder` stage, so `mode=min` would export the runtime stage and
  never the layer the file is designed around.

So the lane builds with no layer cache at all. A cold build measured **139s**,
which is cheaper than it looks because the allowance it frees is restored by
every iOS pull request. If the API comes back into focus, `mode=max` plus a
prune rule that treats the blobs and their index as one all-or-nothing set is
the shape to add: deleting blobs while keeping the index that names them
produces buildkit's `blob not found` import failure rather than a cold build.

## Mutate-response variants, in full

Writes reconcile with the server response directly, with no full-list refetch.
Three create variants live in the codebase.

**Temp-id mutate-response** (`Item`) — the default for new entities. The domain
handler pushes the optimistic entry with a client-generated ulid; the HTTP
wrapper carries that ulid; the `*Created { temp_id, entity }` event replaces the
optimistic entry, since the server-assigned ulid differs from the client one.

**Client-owned ulid** (`Session`) — the client ulid is the canonical id. POST is
fire-and-forget: `SessionSaved` just clears the error state and the model keeps
the optimistic write.

**Save-counter + refetch** (`Set`) — designed as optimistic push, bump
`set_saves_committed`, then a full refetch via `SetSaveSucceeded`, with the
counter driving a save-form's optimistic-to-confirmed UI flip. **Shell-dead
since the coach-pivot builder deletion (#1344):** no Swift screen sends a
`SetEvent`, and `domain/set.rs` fires HTTP unconditionally with no
`local_first` branch. Tracked in #1348 — don't wire a new caller to it, and
don't copy this variant for a new entity, until that's resolved.

Updates use `*Updated { entity }` (the server echoes the row). Deletes use
`DeleteConfirmed`, since the model is already mutated optimistically.

## Glossary

Process words that recur in docs, issues and PR bodies. Feature names don't
belong here: they follow the plain-language rule (CLAUDE.md → Conventions),
which names the musician-visible outcome and allows a codename in brackets
once.

- **slice** — the smallest independently shippable piece of a feature; each
  one is shipped and used before the next is built.
- **stream** — one line of work in one worktree and session; *vertical* means
  core + iOS together.
- **tier** — ceremony level per CLAUDE.md Workflow: 1 just do it, 2 plan
  mode, 3 spec first.
- **fast tier / full tier**, the two iOS test gates: `just ios-test` (unit and
  snapshot) and `just ios-test-full` (adds XCUITests, the merge gate). Not the
  ceremony tier above.
- **the lane**, the TestFlight release workflow
  (`.github/workflows/release-testflight.yml`); runs on a tag only.
- **the stamp**, the freshness fingerprint the iOS recipes write so an
  unchanged tree skips a stage; delete it to force every stage to run.
- **hero**, the large block at the top of the Practice tab: the Up next
  suggestion where one exists, the plain hero otherwise.
- **worktree** — a separate git checkout so parallel streams don't collide.
- **bridge** — the generated FFI boundary (Event / Effect / ViewModel)
  between the Rust core and the Swift shell.
- **local-first** — works offline against the on-device store; no HTTP on
  the path.
- **projection / derived** — computed from existing session history; no new
  stored data.
- **shell-dead** — core code no Swift screen calls any more; a deletion
  candidate (the #1348 pattern).

## Why mutation-test by deletion, not inversion (#1423)

Two derivations shipped in a PR whose own author had "mutation-tested" both by
inverting them. The reviewer deleted each and the full 695-test suite stayed
green. One of the two, replaced with its naive form, would have silently
dropped a tempo the user had earned. Inverting is the weaker mutation because
a reversed sort fails any assertion about order whether or not the test
actually constrains anything — deleting the line (or substituting the naive
version a future reader would plausibly write) is what surfaces a test that
passes for the wrong reason. The resulting rule is in CLAUDE.md under
*Testing*.

## Why hand-picked test cases hid a real bug (#1256)

The coach-era criterion parser shipped with fourteen green unit tests and
still read "three clean passes **in a row**" as the key of A, which at two
keys silently doubled the gate. Every one of those tests used a sentence
written to match the scanner, so they agreed with the implementation by
construction instead of constraining it. The fix is to write the test table
as inputs a *user* would actually produce and assert the property the next
stage needs. The resulting rule is in CLAUDE.md under *Testing*.

## Why #1214 got two independent implementations (2026-08-07)

#1214 got two complete independent implementations (#1243, #1247) fifteen
hours apart. The merged one was the weaker, and #1250 had to port back what
was lost. The issue carried no assignee, label or comment, and nothing
required looking at the one live claim signal, which is an open PR.
`just status` now puts both signals on one screen. The resulting claim
protocol is in CLAUDE.md under *Always*(1).

## Worked tier examples

The tier decision rule is in CLAUDE.md under *Workflow*. These are the calls
that were genuinely arguable when it was written.

|Task|Tier|Why|
|---|---|---|
|Fix typo in a label|1|Trivial copy change|
|Bump a dependency with no API change|1|Dep bump|
|New "Recently practiced" view following existing list patterns|2|Established patterns|
|Refactor `intrada-core/src/domain/session.rs` (no FFI change)|2|Single file, non-trivial|
|Tweak retry backoff in `auth.rs`|2|Sensitivity override from Tier 1|
|Add `notes` field to a piece (touches FFI + DB)|3|Override: FFI + schema|
|New auth provider|3|Auth + multi-crate|
|Migrate persistence layer|3|Architectural|

## Why nothing unread stays in the tree (#1176)

Code with no reader gets deleted rather than parked. Not
`#[allow(dead_code)]`, not "inert until the feature returns", not a `pub`
export nobody calls: those go stale silently, carry weight into the app, and
mislead the next reader into thinking something is load-bearing. `git` is the
parking space, so the deletion goes in the PR body along with the PR number to
recover it from, and whatever doc described the code keeps the *findings*
rather than the code that produced them.

This binds deliberately-deferred work too. The MIDI capture spike and its Rust
segmentation module were deleted on exactly this rule even though the scoring
path is expected back, with
[`segmentation-findings.md`](segmentation-findings.md) left as the record.
Deferring a feature means deferring its code to history.

The distinction that keeps this from over-firing: a stub a *test* reads, or an
API a shell genuinely calls, has a reader. The question is "who reads this
today?", never "might someone read this eventually?".

## Why a test whose arrange already satisfies its assert is worthless (#1223)

Three tests landed on one branch asserting a condition the setup had already
established one line earlier. Each passed for the wrong reason and looked like
coverage for as long as it survived. The check before writing an assertion is
to ask what the value was immediately before it.

When one turns up, mutation-test it (delete the line it names, see whether it
fails) before hardening it. If nothing can distinguish the behaviour being
present from absent, the honest fix is to delete the test, never to bulk it out
with assertions about something else while keeping the name. The resulting rule
is in CLAUDE.md under *Testing*.

## Why the crash-recovery blob is wire-pinned

`AppEffect::SaveSessionInProgress(ActiveSession)` is positional bincode stored
in UserDefaults, written by one build and read by the next. Adding a field
anywhere in `ActiveSession`'s transitive graph therefore makes an old blob
decode into a valid-looking wrong session rather than failing. `#[serde(default)]`
does nothing here, because serde never reaches the default on a
non-self-describing wire.

The coach era missed this three times (#1223, #1244, #1256) and answered it
with a per-variant wire-pin test. `active_session_blob_wire_is_pinned`
(`domain/session.rs`) now pins the blob the same way (#1345). When it fails,
bump `Store.sessionInProgressKey` first, then re-pin. Never only re-pin.

## Why docs and issues use plain language (2026-08-14)

Jon's rule, from a week in which three unrelated "Phase B"s existed at once.
Features get named by the musician-visible outcome ("exercises from a chord
chart", "the Up next card"), with the codename in brackets once if git
archaeology needs it. Issue numbers are the only stable handles, so bare
workstream letters never cross document boundaries, and issue titles state the
outcome rather than the mechanism.

The sweep test is whether you would say the sentence to a musician. Process
words are the exception and live in the glossary above. Older docs get renamed
as they are touched, never swept.

## The comment density gate

The `pre-push` hook (under `.githooks/`) flags branches pushing too many
comment lines relative to code, exempting diffs under 25 added code lines.
Bypass a genuinely justified case locally with `SKIP_COMMENT_CHECK=1 git push`;
in CI, add the `comments-justified` label to the PR instead. When invoking any
code-review agent for a PR, include "comment-policy violations are Blockers,
not Nits" so the review treats drift as a merge-blocker rather than a taste
note. The policy itself is in CLAUDE.md under *Code Style*.

## iOS authentication flow

Google OAuth runs in Safari via `ASWebAuthenticationSession`, because Google
blocks OAuth in an in-app browser. The Clerk JWT is exchanged for a long-lived
PAT via `POST /api/auth/ios/exchange`, and every later call uses the PAT.

JWTs are RS256, validated against JWKS; PATs are validated by SHA-256 hash
lookup. All DB queries are scoped by `user_id`, taken from the JWT `sub` or the
PAT owner. When `CLERK_ISSUER_URL` is unset, auth is disabled, which is local
dev only.

Key files: `intrada-api/src/auth.rs`, `intrada-api/src/routes/auth_ios.rs`,
`intrada-api/src/clerk.rs`.

## How a rule leaves CLAUDE.md (2026-09-08)

`CLAUDE.md` is paid for on every request, in every session and again in every
subagent, so its cost is the one thing in this repo that scales with how much
work we do rather than with how much code exists.

The problem is not that the file only grows. In the 90 days to 2026-09-08 it
took 45 commits, which added 1572 lines and removed 1958: a net reduction of
386. The problem is the shape of that pruning. Almost all of the removal came
from three deliberate sweeps (#1240, #1086, and the #1592 and #1593 trims),
while the commits in between added a rule at a time. So rules accumulate for
weeks, someone notices the file has become unreadable, and a large sweep cuts it
back. This mechanism is for pruning continuously instead, so the sweeps stop
being necessary.

**Three exit routes, in order of preference.**

1. **A gate replaced it.** The moment a rule becomes a test, a CI check, a
   commit hook or a permission entry, its prose is dead and comes out in the
   same change that adds the gate. `scripts/check-dashes.sh` is the model: the
   dash ban is enforced on changed lines, so the prose only has to say what the
   gate cannot see (double dashes, commit messages, PR bodies). A rule that is
   both gated and written is worse than either alone, because the two drift and
   the reader cannot tell which is current.

2. **The incident aged out.** A rule that cites a specific failure is trusted
   and kept; a rule that reads as dogma gets cargo-culted or ignored. But an
   incident more than 90 days old has usually either stopped recurring, in which
   case the rule can go, or recurred, in which case it deserves a gate rather
   than more prose. At review time, every dated rule answers "has this happened
   since?". No is a delete, yes is a gate.

3. **The surface went away.** A rule about a deleted crate, a retired harness or
   a superseded pattern is not history, it is misdirection: an agent reads it as
   current and plans around a constraint that no longer exists. These come out
   the moment the surface does, and the *finding* moves here if it is worth
   keeping.

**What never leaves.** Invariants whose breach is silent. The bincode bridge
being positional, migrations being append-only, the device being the only copy
of a free-tier user's data: no gate covers the judgement of noticing you are
about to break one, and no amount of elapsed time makes them safer.

**Where the deleted prose goes.** Here, if the reasoning is worth keeping, as a
dated section like this one. Otherwise nowhere: `git` is the parking space, the
same rule that applies to dead code (#1176). Do not leave a rule in place with a
note saying it is obsolete.

## Known tech debt (moved from CLAUDE.md, 2026-09-08)

- **`Set`** (`domain/set.rs`) is shell-dead and violates offline-first
  invariant 1: no Swift screen sends a `SetEvent`, and its HTTP creates fire
  unconditionally with no `local_first` branch or persistence op. #1348 decides
  whether it is deleted or converted before `RoutinesScreen` is wired to it.
- **Session reflection** (`reflection_improved`, `reflection_still_rough`,
  `reflection_next_target`, `ReflectionField`,
  `SessionEvent::UpdateSessionReflection`) is shell-dead the same way after
  #1368 removed the UI. Removing it is a domain-sensitivity change (bridge plus
  schema), so it stayed. Tracked in #1374.

## Why OMP was retired (2026-09-08)

Two harnesses meant every definition existed twice (reviewer, test-runner, the
format hook, and two guides that disagreed on which agents existed), and the
only OMP failures the repo recorded were drift between the copies and prewalk
arming twice without firing. Every OMP mechanic has a native Claude Code home:
role pins with effort bound are agent frontmatter `model` and `effort`, plus
`/model` and `/effort` in-session; sticky rules near the turn are a
`UserPromptSubmit` hook; bash patterns are the `guard-bash` hook; the `slow`
role for silent-failure surfaces is `.claude/rules/sensitive-surfaces.md`,
which loads when one of those files is read; compressed research is the
`Explore` agent; isolated clones are `just worktree-new`, which also seeds the
iOS build cache a clone did not carry. The retired `.omp/` config is
recoverable from the commit before this section landed.
