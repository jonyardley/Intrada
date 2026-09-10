# intrada Development Guidelines

<!-- Rules and invariants only; loads into every session and subagent, so it
stays under 200 lines. Mechanics and incidents: docs/reference.md. Surface-bound
rules live in .claude/rules/. A rule leaves when a gate enforces it, when its
incident is over 90 days old and has not recurred, or when its surface is
deleted; silent-breach invariants never leave. Last reviewed: 2026-09-08. -->

## Focus: native iOS only

The native SwiftUI app on the Crux core is the **only** shell
([`specs/native-ios.md`](specs/native-ios.md)). The Leptos web shell and the
Tauri iOS host were deleted in 2026-07 (`docs/rebuild-review.md`): never resurrect
them or assume they exist. **A request implying web work: confirm the platform first.**

## Project

intrada is a **practice notebook** for musicians: build a session from the music
library, group and reorder what you'll practise, play it through with a timer
and rep counting, and score how it went. Pillars: **Plan** (library),
**Practice** (the built session), **Track** (analytics). Direction:
[`docs/roadmap.md`](docs/roadmap.md); release and phase:
[`docs/where-we-are.md`](docs/where-we-are.md); what is in flight:
`just status`, which reads GitHub. There is no status file, deliberately.

Crates: `intrada-core` (pure Crux core, no I/O), `intrada-ffi` (UniFFI bridge
generating the Swift bindings), `intrada-api` (axum 0.8 + Turso on Fly.io).
`ios/` is the SwiftUI app (iOS 17+, GRDB on-device); `ios/Reference/` holds two
unbuilt Swift pieces from the removed Tauri shell. Rust 2021, MSRV 1.90.

## Commands

```bash
just check            # fmt-check, lint, test, hygiene; mirrors CI exactly
just ios              # regen bindings (if core changed) + open Xcode
just ios-run          # build + launch on simulator + screenshot (seeded data)
just ios-test         # unit + snapshot (fast tier)
just ios-test-full    # adds XCUITests (the merge gate; mirrors CI)
```

- **Drive iOS through the `just` recipes, never a bare `xcodebuild` or an MCP
  build call.** They carry the destination pin, `CODE_SIGNING_ALLOWED=NO`, the
  freshness fingerprint and the concurrency guard (#1536, #1537). A passing run
  prints its own counts; silence is never the evidence.
- **Run `just check` before pushing**, plus `just ios-fmt-check` for `ios/`
  (fix with `just ios-fmt`). Local green means CI green; keep the justfile and `ci.yml` in lockstep. Read
  every compile error before fixing the first: `cargo check --all-targets`, and
  the whole `just ios-test` error list.
- **The simulator is machine-global.** `check-sim-free.sh` blocks a run while
  another session's simulator is live and the global resets are denied; before a
  fresh run check `xcrun simctl list devices | grep Booted` and ask if it is not yours.
- **Seed mode skips persistence**: `SEED=0 just ios-run` to test persistence.
- **Read source with the Read tool, not `cat`.** Path-scoped rules fire on Read.

Recipes, binding regeneration, simulator workflow and environment variables:
[`docs/reference.md`](docs/reference.md), [`docs/ios-testing.md`](docs/ios-testing.md).
The graphify graph (`graphify-out/`, main checkout only) answers architecture
questions; grep for symbols; never rebuild it without `.graphifyignore`.

## Architecture (non-negotiables)

```text
User → Events → crux_core (Rust) → Effects (Http, Persistence, App, Render) → Shell (Swift) → I/O
```

1. **Core owns all logic.** HTTP requests are built in core via `crux_http`;
   core does all JSON serialization. The shell never understands domain types.
2. **The shell is a dumb pipe.** It fulfils `HttpRequest` via `URLSession` and
   persistence via GRDB, and renders the `ViewModel`. No business rules,
   validation, domain decisions or domain state in Swift (UI interaction state
   only): if you are tempted, it belongs in `intrada-core` as an `Event` or
   `Command`. Crash recovery: UserDefaults (`AppEffect::SaveSessionInProgress`);
   local data: GRDB (`PersistenceOperation`).
3. **Typed bindings, no hand-written FFI.** `Event` / `Effect` / `ViewModel`
   cross the bridge as generated bincode. Never hand-edit `ios/generated/`; fix
   the Rust type and regenerate.

- **Validation** lives in `intrada-core/src/validation.rs`. **DB**: positional
  column indexing with `SELECT_COLUMNS`; migrations sequential in
  `intrada-api/src/migrations.rs`, one statement each.
- **Mutate response**: writes reconcile with the server response, no refetch.
  Temp-id for new entities, `*Updated { entity }`, `DeleteConfirmed`.
- **Swift**: an `@Observable @MainActor` store, not `ObservableObject`; effect
  handlers run off the main actor and hop back. `try!`, force-unwraps and `as!`
  are banned like `unwrap()`. Persistence is a core `Effect` driven by
  `Command`: GRDB executes typed effects, the core decides reads, writes and
  LWW reconciliation; `crux_kv` is for singletons. Every colour, font, spacing
  and radius is a named token from `Theme.swift`.
- **Auth**: every DB query is scoped by `user_id`; iOS exchanges the Clerk JWT
  (Google OAuth in Safari) for a long-lived PAT (JWT RS256); auth is disabled
  when `CLERK_ISSUER_URL` is unset, which is local dev only.

The offline-first invariants, the UI and tone rules, the per-screen quality bar
and the silent-failure hazards load from `.claude/rules/` when you read a file
they cover, and bind whether or not you have seen them.

## Code style

- `cargo fmt` and `cargo clippy -- -D warnings` pass. No `unwrap()` without
  justification. Prefer established libraries over custom implementations.
- **Code with no reader gets deleted, not parked** (#1176): not
  `#[allow(dead_code)]`, not "inert until the feature returns", not a `pub`
  nobody calls. `git` is the parking space; keep the findings and name the
  recovery PR. A stub a test reads, or an API a shell calls, has a reader.
- **Comments: default to none.** The density gate fails a push that adds too
  many; what it cannot see is the kind. Three are justified: a one-line section
  header (`// ── Validation ──`), a non-obvious WHY citing a concrete reason
  (issue, incident, `BUG:` tag), or `HACK(#N)` / `FIXME(#N)` tied to a tracked
  issue. Never one that restates the code, narrates the task or PR, hedges
  without an issue, or notes that X "mirrors" Y. `///` on a self-evident item
  is the same noise. Over two lines, ask whether it should be a name or a type.
- **British English**; UI copy is written against `docs/tone-of-voice.md`.
  **No em dashes, en dashes or double dashes**: `scripts/check-dashes.sh`
  enforces the first two on changed lines, the rest stays on the author.
  **Plain language in docs, issues and PR bodies**: name features by the
  musician-visible outcome; issue numbers are the only stable handles.

## Testing

**Ship tests with new code.** New endpoints, DB functions and non-trivial pure
logic include tests. The API suite (`crates/intrada-api/tests/`) uses real SQLite
via `common::setup_test_app()`. Endpoints: the auth rejection paths at minimum,
plus the happy path in auth-disabled mode. DB writes: rows affected, idempotency,
cross-user isolation. Pure functions: edge cases, None and empty inputs. New iOS
test files use Swift Testing; migrate an XCTest file only when already touching
it, never wholesale; XCUITest stays on XCTest.

- **Before asserting, ask what the value was one line earlier** (#1223); if
  nothing distinguishes the behaviour present from absent, delete the test.
  **Mutation-test by deleting the line, not inverting it** (#1423).
- **A parser or validator gets a table test against its consumer** from inputs
  a user would produce (#1256); cases you invented agree with your code by
  construction. Fixtures for a many-field type live in one place (Rust
  `fixture()` with struct update, Swift a fixture enum with default arguments).
- **Say so in the PR when you skip tests.** Tier 2+ carries a **Coverage** line
  naming expected gaps before CI finishes, then checks the Codecov comment
  against it (70% patch target, informational; `ios/`, `migrations.rs` ignored).

## Gotchas (each has caught us at least once; write-ups in `docs/reference.md`)

- **JSON-only serde attrs break the bincode bridge silently** (#846), and a
  stub-bridge test cannot catch it: use `LiveBridge`.
- **A field inside the crash-recovery snapshot invalidates every blob** (#1345):
  bump `Store.sessionInProgressKey` first, then re-pin.
- **`option_env!` needs `cargo:rerun-if-env-changed`**, or the rebuild uses the
  stale value (`CLERK_PUBLISHABLE_KEY`, `INTRADA_API_URL`).

## Workflow

Match ceremony to scope; if unsure, go one tier lighter and drift up.

- **Tier 1, just do it**: bug fixes, copy, style, renames, lint, single-file
  refactors, doc updates. Main checkout.
- **Tier 2, plan mode** (default for feature work): a component or screen on
  existing patterns, an endpoint on established conventions, a field on a
  model. UI work does Claude Design first, and a new screen starts by reading an
  existing one, which loads the UI rules. Worktree: `just worktree-new <name>`.
- **Tier 3, lightweight spec** (architectural): net-new top-level features,
  Crux core or bridge changes, auth or schema changes. One `specs/<feature>.md`
  of 100 to 200 lines, riding as the first commit of Phase A, never its own PR.

**Domain-sensitivity override**: auth, the bridge contract, DB schema or
migrations go up at least one tier and up the model ladder. **A phase that
introduces a bridge shape, a migration, or a change inside the `ActiveSession`
blob graph ships as two PRs, core first, screens in the same working session**,
or the core PR waits (#1348, #1374); spanning core and screens is not itself the
trigger. Review the core PR before the screens.

Test-first for non-UI Tier 2, all Tier 3 and `intrada-core` changes by default:
a test retrofit to pass agrees with the implementation by construction (#1256).
Review through the `reviewer` agent for Tier 2+ and triage its findings. Model,
effort and streams per activity, and what a plan must say:
[`docs/working-with-agents.md`](docs/working-with-agents.md). **UI verification
means driving the app on the simulator**; if you cannot, say what needs a hand check.

### Always

1. **Claim the issue before building it, and check nobody else has** (#1214):
   `gh pr list --state open --search "N"` and
   `gh issue view N --json closedByPullRequestsReferences`. A PR already open
   means stop and say so; otherwise add `in-flight` and comment the branch, and
   drop the label when the PR closes. Handover openers start with the claim.
2. Find the roadmap item, or discuss first; check the
   [project board](https://github.com/users/jonyardley/projects/2). Read the
   issue and what it points at before any code, then plan and state resourcing.
3. **Always a feature branch and a PR; a human merges.** Branch protection
   refuses a push to main and `gh pr merge` is denied in settings. CI green is
   the session's job: after every push watch the run to a conclusion, react, push
   again, and surface the PR only when green or stuck. Read the PR's mergeability,
   not just the job list: a renamed job leaves its old context "expected" for ever (#1542).
4. **Ship through `/ship`**, which follows
   [`.claude/skills/intrada-shipping/SKILL.md`](.claude/skills/intrada-shipping/SKILL.md).
5. **After completing work**: close the issue and drop `in-flight` (that is the
   status update); update `docs/roadmap.md` and `docs/where-we-are.md`
   if a phase changed, this file if architecture did; `just worktree-rm` once merged.

**More than one session at once** follows
[`.claude/skills/intrada-parallel-streams/SKILL.md`](.claude/skills/intrada-parallel-streams/SKILL.md);
both skills bind whether or not you loaded them.
