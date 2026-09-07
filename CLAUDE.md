# intrada Development Guidelines

> **Rules and invariants only.** This file loads into every session, so it stays
> short. The mechanics behind each rule, and the incident it came from, live in
> [`docs/reference.md`](docs/reference.md), read on demand.
>
> Last reviewed: 2026-09-07.

## Focus: native iOS only

The native SwiftUI app on the Crux core is the **only** shell
([`specs/native-ios.md`](specs/native-ios.md)). The Leptos web shell
(`crates/intrada-web`) and the Tauri iOS host (`crates/intrada-mobile`) were
deleted in 2026-07: never resurrect them, and never add a feature assuming they
exist. **If a request seems to imply web or Leptos work, confirm the platform
before writing code.** Two Swift pieces worth reusing sit unbuilt under
`ios/Reference/`. Rationale:
[`docs/rebuild-review.md`](docs/rebuild-review.md).

## Project

intrada is a **practice notebook** for musicians: build a session from the music
library, group and reorder what you'll practise, play it through with a timer
and rep counting, and score how it went. Three pillars: **Plan** (library),
**Practice** (the built session), **Track** (analytics).

- Direction and phases: [`docs/roadmap.md`](docs/roadmap.md)
- Which release and phase: [`docs/where-we-are.md`](docs/where-we-are.md)
- What is in flight: `just status`, which reads GitHub. There is no status file,
  deliberately.

```text
crates/
  intrada-core/          # Pure Crux core: business logic, no I/O
  intrada-ffi/           # UniFFI bridge: generates the Swift bindings
  intrada-api/           # REST API: Axum 0.8 + Turso (libsql)
ios/                     # Native SwiftUI app (Intrada.xcodeproj via xcodegen)
  Reference/             #   Swift kept from the removed Tauri shell (not built)
.claude/skills/          # Repo rules loaded on demand
design/                  # Claude Design system
docs/                    # Roadmap, status, operational reference
specs/                   # Spec docs for major features (Tier 3 only)
```

**Stack**: Rust stable, 2021 edition, MSRV 1.90 via crux_core 0.20 (serde, ulid,
chrono, thiserror). API: axum 0.8, tokio, libsql 0.9 (Turso), tower-http,
jsonwebtoken 10. iOS: SwiftUI on iOS 17+, UniFFI + facet typegen, GRDB
on-device. Auth: Clerk (Google OAuth) exchanged for a long-lived PAT, JWT RS256.
CI/CD: GitHub Actions to Fly.io and TestFlight.

## Commands

```bash
just check                 # fmt-check, lint, test, hygiene; mirrors CI
just ios-fmt-check         # Swift formatting gate (fix with just ios-fmt)
just ios                   # regen bindings (if core changed) + open Xcode
just ios-run               # build + launch on simulator + screenshot
just ios-test              # unit + snapshot (fast inner-loop tier)
just ios-test-full         # adds XCUITests (the merge gate; mirrors CI)
```

Full recipe list, TestFlight, binding regeneration and the demo-data schemes:
[`docs/reference.md`](docs/reference.md). Simulator workflow, worktree
isolation and the green-stamp skip: [`docs/ios-testing.md`](docs/ios-testing.md).

- **Drive iOS through the `just` recipes, never a bare `xcodebuild` or an MCP
  build call.** The recipes carry the destination pin, `CODE_SIGNING_ALLOWED=NO`,
  the build-freshness fingerprint and the concurrency guard; an invocation
  missing any of them fails in ways that look like repo faults and are not
  (#1536, #1537). A passing run prints its own counts, so silence is never the
  evidence.
- **Run `just check` locally before pushing**, not just before committing. The
  recipes mirror CI's flags and crate exclusions exactly, so local green means CI
  green (cargo-deny and Gitleaks are CI-only). Changes under `ios/` also need
  `just ios-fmt-check`. Keep the justfile and `ci.yml` in lockstep when either
  changes.
- **Read every compile error before fixing the first.** Use
  `cargo check --all-targets`, not `cargo build`, so test-code breakage surfaces
  in the same pass as the lib. Same for Swift: read the whole `just ios-test`
  error list, then fix.
- **The simulator is machine-global.** Before any global reset
  (`simctl shutdown all`, `killall CoreSimulatorService`) or a fresh test run,
  check for another live session (`xcrun simctl list devices | grep Booted`;
  `pgrep -fl 'xcodebuild|XCTestAgent'`). If anything you didn't start is active,
  **pause and ask the user** rather than risk killing their sim or tests.
- **Seed mode skips persistence.** `--seed-sample-data` (the **Intrada (Seeded)**
  scheme, and `just ios-run`'s default) replaces the model with demo items and
  skips store hydration, so never use it when testing persistence. Use
  `SEED=0 just ios-run` for real on-device data.

## Knowledge graph (graphify)

A graphify graph of the repo lives in the **main checkout** at `graphify-out/`
(gitignored; worktrees don't carry it). **Query it first** for architecture,
cross-document or spec-archaeology questions; for symbol-level navigation use
grep or LSP instead, which is faster and always current. An empty or weak result
means the graph can't answer it, so fall back to grep rather than triggering a
rebuild for one question. **Never build or update the graph without the
committed `.graphifyignore` in place.** Commands:
[`docs/reference.md`](docs/reference.md).

## Architecture (non-negotiables)

```text
User → Events → crux_core (Rust) → Effects (Http, Persistence, App, Render) → Shell (Swift) → I/O
```

1. **Core owns all logic.** HTTP requests are built in core via `crux_http`, and
   core does all JSON serialization. The shell never understands domain types.
2. **The shell is a dumb pipe.** It receives `HttpRequest` (URL, method, headers,
   bytes), fulfils it via `URLSession`, returns `HttpResponse`. No domain imports.
3. **Typed bindings, no hand-written FFI.** `Event` / `Effect` / `ViewModel`
   cross the bridge via generated bincode serializers (facet typegen + UniFFI).
   Swift never hand-encodes a domain type.

### State boundary

|State kind|Where it lives|
|---|---|
|Domain data|Crux `Model` → `ViewModel` (single source of truth)|
|UI interaction|SwiftUI `@State` / `@Observable` view state|
|Crash recovery|iOS UserDefaults (`AppEffect::SaveSessionInProgress`)|
|Local-first persistence|On-device GRDB/SQLite (`PersistenceOperation` effect)|

Domain state flows through `Event` → `Model` → `ViewModel`. Never store domain
data in shell-local state. UI-only state stays in SwiftUI.

### Other patterns

- **Validation**: `intrada-core/src/validation.rs` is the single source of truth.
- **DB**: positional column indexing with the `SELECT_COLUMNS` const.
- **Migrations**: sequential in `intrada-api/src/migrations.rs`, one SQL
  statement each.
- **Mutate response**: writes reconcile with the server response directly, with
  no full-list refetch. **Default to temp-id for new entities** (`Item`). The
  client-owned-ulid variant (`Session`) and the shell-dead `Set` variant are
  detailed in [`docs/reference.md`](docs/reference.md). Updates use
  `*Updated { entity }`; deletes use `DeleteConfirmed`.

## Native iOS shell (SwiftUI + Crux)

**The shell owns ZERO domain logic.** It sends `Event`s, fulfils `Effect`s (HTTP
via `URLSession`, persistence via GRDB) and renders the `ViewModel`. No business
rules, no validation, no domain decisions in Swift. If you are tempted to write
logic in Swift, it belongs in `intrada-core` as an `Event` or `Command`.

- **Bindings are a build precondition, never source.** The Swift `Event` /
  `Effect` / `ViewModel` types and serializers are generated. **Never hand-edit
  generated bindings**: fix the Rust type and regenerate. A diff that edits
  generated Swift is a blocker.
- **`@Observable`, not `ObservableObject`.** The core-wrapping store is an
  `@Observable @MainActor` object exposing the `ViewModel` and `update(Event)`.
  Effect handlers run off the main actor, then hop back to resolve.
- **`try!` is banned like `unwrap()`.** No `try!`, force-unwraps or `as!`
  without written justification. FFI and bincode calls return real errors.
- **Persistence is a core `Effect` driven by `Command`, not Swift logic.** GRDB
  owns the tables and executes typed effects; the core decides what to read and
  write and runs LWW reconciliation. `crux_kv` is for small singletons only.
- **Quality is per-screen, not deferred.** Every screen ships with a
  swift-snapshot-test, VoiceOver labels, Dynamic Type, and an iPad `SplitView`
  built *with* the screen. Sentry is wired from the first build.
- **Every colour, font, spacing and radius value is a named token** from
  `Theme.swift`. Genuine one-offs (a fixed component height, a 2pt baseline
  nudge) stay literal.
- **Build hazard**: UniFFI-generated Swift fails under Xcode 26 / Swift 6.2
  `MainActor`-default isolation ([uniffi-rs#2818]). The build recipe keeps the
  generated package non-MainActor-defaulted; don't "fix" it by editing
  generated code.

[uniffi-rs#2818]: https://github.com/mozilla/uniffi-rs/issues/2818

**Before adding or changing a screen, or touching
`ios/IntradaTests/__Snapshots__`, you MUST read `skill://intrada-ios-quality`**
for the per-screen quality bar and snapshot hygiene rules.

**Before any change touching persistence, sync, a new domain entity, the local
schema, or gating a feature behind sign-in, you MUST read
`skill://intrada-offline-first`** for the eight numbered invariants, the PR
checklist and the local-migration rules. Break one and the app silently stops
being offline, and on the free tier the device is the only copy of the user's
data.

Both bind whether or not you loaded them.

## Authentication

All DB queries are scoped by `user_id`. iOS runs Google OAuth in Safari and
exchanges the Clerk JWT for a long-lived PAT. Auth is disabled when
`CLERK_ISSUER_URL` is unset, which is local dev only. Flow, validation and key
files: [`docs/reference.md`](docs/reference.md). Environment variables for every
crate and the iOS build are there too.

## Design system

The native app uses a "Paper & Score" light theme. Hand-rolled views that
duplicate an existing primitive are the number one source of visual drift.

**Before any UI or UX change you MUST read `skill://intrada-design-system`** for
enforcement, **`skill://intrada-design-principles`** for how the app should
feel, and **`skill://intrada-tone-of-voice`** for every user-facing string.
These bind whether or not you loaded them. Keep
`design/intrada-design-system.dc.html` current when UI diverges from design.

## Code style

- Rust stable, 2021 edition. `cargo fmt` and `cargo clippy -- -D warnings` must
  pass. No `unwrap()` without justification.
- Prefer well-established libraries over custom implementations.
- **Code with no reader gets deleted, not parked.** Not `#[allow(dead_code)]`,
  not "inert until the feature returns", not a `pub` export nobody calls. `git`
  is the parking space: delete it, name the recovery PR in the body, and keep
  the *findings* rather than the code. This binds deferred work too (#1176).
  The test is "who reads this today?", not "might someone read this eventually?".
  A stub a *test* reads, or an API a shell calls, has a reader.

### Comments

Default to **no comments**. Self-explanatory code with well-named identifiers
beats commented code. A comment is justified ONLY in one of three buckets;
everything else gets deleted.

1. **Section headers in a large file**, single-line dividers like
   `// ── Validation ──`. Never more than one line. A one-line cross-file
   pointer the reader would otherwise miss counts here too.
2. **Unusual things that need explaining**: a non-obvious WHY, such as a hidden
   constraint, a subtle invariant, a workaround for a specific bug, or a
   framework quirk that would surprise a reader. Cite the reason concretely
   (issue number, incident, doc link, `BUG:` tag). Vague WHY is no better than
   restating WHAT.
3. **Hacky code that needs rework**, tied to a tracked issue: `// HACK(#N): …`
   or `// FIXME(#N): …`. A bare `// TODO come back to this` is not acceptable.

`///` doc comments get the **same** treatment: a `///` narrating a self-evident
private item is noise. Delete it.

Never write a comment that restates WHAT the code does; narrates self-evident
styling or structure; references the current task or PR (`// Added for #719`,
which rots and belongs in the PR description); apologises or hedges without a
tracked issue; or notes that a function "Mirrors X" when the shapes make it
obvious.

Two-line cap as a smell test: if a comment runs longer, ask whether it can be a
function name, a type, or a CLAUDE.md entry. Usually yes. Gate mechanics and the
bypass: [`docs/reference.md`](docs/reference.md).

## Testing

**Default: ship tests with new code.** New API endpoints, DB functions and
non-trivial pure logic must include tests. The suite
(`crates/intrada-api/tests/`) uses real SQLite via `common::setup_test_app()`,
so no mocks are needed.

- API endpoints: at minimum the auth rejection paths; happy path when reachable
  through the harness (auth-disabled mode gives a fake user).
- DB write functions: rows affected, idempotency, cross-user isolation.
- Pure functions: edge cases, None and empty inputs.

**iOS framework policy**: new unit and snapshot files use **Swift Testing**
(`import Testing`). Migrate existing XCTest files only when already touching
them, never wholesale. XCUITest (`IntradaUITests`) stays on XCTest.

- **Before asserting, ask what the value was one line earlier.** A test whose
  arrange step already satisfies its assert passes for the wrong reason and
  looks like coverage forever (#1223). If nothing can distinguish the behaviour
  being present from absent, **delete** the test rather than bulking it out with
  assertions about something else while keeping the name.
- **Mutation-test by deleting the line, not by inverting it** (#1423). Delete
  the sort, filter, guard or clamp and see whether anything goes red; inverting
  is the weaker mutation and hides exactly the failure above. If deletion won't
  compile, substitute the naive version a future reader would plausibly write.
- **A parser or validator gets a table test against its consumer**, built from
  inputs a *user* would actually produce, asserting the property the next stage
  needs. Cases you invented agree with your implementation by construction
  (#1256).
- **Fixtures for a type with many fields live in one place.** Rust: a
  `fixture()` constructor composed with struct update
  (`Record { exit: Exit::Skipped, ..fixture() }`). Swift: a fixture enum whose
  default arguments do the same. Adding a field should cost one edit.
- **Say so in the PR when you skip tests**, with the reason. "All 157 tests
  pass" is not coverage: those are existing tests.

**Coverage** (Codecov, `codecov.yml`): PRs get a patch-coverage comment (70%
target, informational). **Tier 1** needs no justification. **Tier 2+** must
carry a **Coverage** line naming expected gaps *before* CI finishes, then check
the Codecov comment against it; if it is below 70% for reasons you didn't
anticipate, push tests or explain in a PR comment. Ignored paths: `ios/`,
`migrations.rs`.

## Gotchas

Bear-traps that have caught us at least once. Full write-ups:
[`docs/reference.md`](docs/reference.md).

- **JSON-only serde attrs break the bincode FFI bridge.** The bridge is
  positional bincode, which has no "absent". Be wary of `deserialize_with` /
  `serialize_with`, and of `skip_serializing_if` on non-trailing fields, on
  anything crossing the bridge. Branch on `Deserializer::is_human_readable()`
  when you need format-specific behaviour. The symptom is a **silent no-op**,
  not a crash (#846).
- **Stub-bridge tests can't catch a wire break.** Cover bridge-crossing types
  with a *real*-bridge round-trip (`LiveBridge` in `StoreEffectLoopTests`).
- **Adding a field inside the crash-recovery snapshot invalidates every blob on
  every device.** `active_session_blob_wire_is_pinned` (`domain/session.rs`)
  pins it (#1345). When it fails, bump `Store.sessionInProgressKey` first, then
  re-pin; never only re-pin.
- **`option_env!` needs `cargo:rerun-if-env-changed`.** Without it cargo caches
  the macro expansion and your "I changed the env var" rebuild silently uses
  stale values. Hit on `CLERK_PUBLISHABLE_KEY` and `INTRADA_API_URL`.

## Workflow

Match ceremony to scope. Default to less; if unsure between tiers, go one
lighter and drift up if scope expands.

- **Tier 1, just do it.** Bug fixes, copy changes, style tweaks, renames, lint
  fixes, single-file refactors, dependency bumps, doc updates. No plan mode, no
  spec. Read enough to confirm the change, make it, verify, ship.
- **Tier 2, plan mode** (the default for feature work). A new component or
  screen following existing patterns, a new endpoint on established
  conventions, a field on an existing model. UI work does Claude Design first.
  No spec doc.
- **Tier 3, lightweight spec** (rare, architectural only). Net-new top-level
  features, Crux core or FFI bridge changes, auth or DB schema changes,
  multi-week work spanning core + API + iOS. One markdown doc in
  `specs/<feature>.md`, 100 to 200 lines, then design, then plan, then build.

**Domain sensitivity override**: changes to auth, the FFI bridge contract
(Event / Effect / ViewModel), DB schema or migrations go up at least one tier
regardless of file count or apparent size. It applies to model choice too.

**The spec rides with the first implementation phase**, as the first commit on
the Phase A branch, never its own PR. Reviewers sanity-check it against working
code. Phases B onward ship as their own PRs.

**A phase that introduces a bridge shape, a migration, or a change inside the
`ActiveSession` blob graph ships as two PRs: core first, screens second.** The
screens PR is expected in the same working session, or the core PR waits: a
merged core PR with no caller is shell-dead by construction, which is how #1348
and #1374 happened. Spanning core and screens is not itself the trigger, since
a phase with no silent-failure surface fails visibly. **Review the core PR
before starting the screens.**

Worked tier examples: [`docs/reference.md`](docs/reference.md). Tiers set the
ceremony; [`docs/model-guide.md`](docs/model-guide.md) sets the model and
reasoning effort per activity, and what every plan must say about parallel
streams. `/speckit-*` slash commands are deprecated: never invoke them.

### Practices worth invoking deliberately

Invoked by name, deliberately, not blanket-applied. In OMP these resolve as
`skill://<name>`; in a harness with no catalogue, read the `SKILL.md` directly.

- **Test-first** for non-UI Tier 2 work, all Tier 3 work, and by default for
  `intrada-core` changes (`domain/*.rs`, `validation.rs`, `http.rs`,
  `model.rs`). The #719 delete-404 bug shipped because the test was retrofit to
  pass rather than written to constrain. Skip for visual or gesture work
  verified on-device. (`test-driven-development`.)
- **Request review** as the standard channel for Tier 2+ PRs, rather than
  hand-rolling a prompt each time. (`requesting-code-review`; OMP: the
  `reviewer` agent via `task`.)
- **Read review findings before acting on them**, triaging real blockers from
  noise rather than mechanically applying every comment.
  (`receiving-code-review`.)
- **Isolate concurrent branches in separate worktrees** when two or more PR
  branches are in flight. (`using-git-worktrees`; OMP: `isolated` on `task`.)

**UI verification means actually driving the app on the simulator**, not
claiming "all green" when that means cargo test green. If you can't reach the
running app, say exactly what needs user verification.

### Picking up a work item

Steps 1 to 4 all happen before any code is written, and step 3 before any code
is read.

1. **Claim it** per *Always*(1), and stop if someone else already has.
2. **Work in a worktree** for Tier 2 and above: `just worktree-new <name>`
   branches from fresh `origin/main` and seeds the warm `target/` and
   `ios/build` caches. Tier 1 stays in the main checkout, which is also the only
   place `graphify-out/` exists.
3. **Read the issue and what it points at**: the body, its linked issues and
   PRs, and the roadmap item. An issue citing a spec or an earlier PR is naming
   the constraints; a plan written without them gets rewritten in review.
4. **Plan, and state the resourcing in one line**: the model and effort this
   session runs at ([`docs/model-guide.md`](docs/model-guide.md)), and what goes
   to a subagent. One vertical slice stays with one agent
   (`skill://intrada-parallel-streams`); only genuinely independent pieces
   (audits, sweeps, docs, API-only work) fan out.

### Always

1. **Claim the issue before building it, and check nobody else has.** First
   action on picking up issue N, before reading code:
   `gh pr list --repo jonyardley/intrada --state open --search "N"` and
   `gh issue view N --json closedByPullRequestsReferences`. If a PR is already
   open against it, **stop and say so** rather than implementing it again. If
   clear, add the `in-flight` label and comment the branch name on the issue.
   Drop the label when the PR merges or closes. This binds any session
   *recommending* the next task or writing a handover opener too: never name an
   issue as next without running it, and start every opener with "claim #N (stop
   if a PR already exists)". (#1214.)
2. Find the roadmap item in [`docs/roadmap.md`](docs/roadmap.md). No item means
   discuss first.
3. Check priority on the
   [project board](https://github.com/users/jonyardley/projects/2).
4. **Never push to main. Always a feature branch and a PR. A human reviews and
   merges; agents never merge.** Getting CI green is the session's job, not the
   reviewer's: after every push, watch the run to a conclusion, react to what
   fails, push again, and only surface the PR once it is green or genuinely
   stuck. Red is something to fix, not to report. Read the PR's mergeability
   too, not just the job list: a renamed job leaves its old required context
   "expected" for ever, so the PR hangs on a check that will never report and no
   job ever fails (#1542).
5. **Open or update any non-trivial PR through a single pre-push gate.** Before
   pushing, read `skill://intrada-shipping` for the gate mechanics, Codecov
   expectations, the deferred-issue protocol and the PR and issue body
   templates. They bind whether or not you loaded it.

### After completing work

1. Close the GitHub issue and drop its `in-flight` label. That *is* the status
   update, since `just status` reads GitHub. Update
   [`docs/roadmap.md`](docs/roadmap.md) if a phase or direction changed, and
   [`docs/where-we-are.md`](docs/where-we-are.md) if the release or phase did.
2. Update this file if architecture or patterns changed.
3. Update `design/intrada-design-system.dc.html` if UI diverged from design, and
   re-export the shareable `.html`.
4. Remove the worktree once the PR merges: `just worktree-rm <name>`, which also
   deletes that worktree's throwaway simulator.

## Parallel work streams

More than one agent session against this repo at once is allowed, but only under
rules that stop two streams colliding in the same files. **Before starting a
second concurrent stream, fanning out to subagents, or coordinating worktrees
you MUST read `skill://intrada-parallel-streams`** for the decoupled file set,
the serialisation points, one-agent-per-vertical-slice and the definition of
done. It binds whether or not you loaded it.

### Conventions

These bind every change, concurrent or not.

- **British English** in all UI copy, comments, commit messages and PR bodies.
  UI copy has its own rules on top: `skill://intrada-tone-of-voice`.
- **No em dashes, en dashes or double dashes** in prose, comments, commits or PR
  bodies. `scripts/check-dashes.sh` enforces the em and en dash ban on changed
  lines (CI and pre-push; bypass a justified case with `SKIP_DASH_CHECK=1`).
  Double dashes, commit messages and PR bodies stay on the author, since the
  gate cannot see them.
- **Plain language in docs, issues and PR bodies.** Name features by the
  musician-visible outcome, with the codename in brackets once if git
  archaeology needs it. Issue numbers are the only stable handles: never bare
  workstream letters across docs. Issue titles state the outcome. Sweep test:
  would you say the sentence to a musician? Process terms live in the glossary
  in [`docs/reference.md`](docs/reference.md); older docs are renamed as
  touched, not swept.

## Known tech debt

- **`Set`** (`domain/set.rs`) is shell-dead and violates offline-first invariant
  1: no Swift screen sends a `SetEvent`, and its HTTP creates fire
  unconditionally with no `local_first` branch or persistence op. #1348 decides
  whether it is deleted or converted before `RoutinesScreen` is wired to it.
- **Session reflection** (`reflection_improved` / `reflection_still_rough` /
  `reflection_next_target`, `ReflectionField`,
  `SessionEvent::UpdateSessionReflection`) is shell-dead the same way after
  #1368 removed the UI, but removing it is a domain-sensitivity-override change
  (FFI bridge plus DB schema), so it stayed. Tracked in #1374.
