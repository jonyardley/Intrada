# Working with coding agents on intrada

> One reference for driving this repo from a coding agent, covering both
> harnesses in use: Claude Code and OMP (`omp.sh`, usually inside cmux).
> Replaces the separate `working-with-claude-code.md` and `working-with-omp.md`,
> which had drifted apart and contradicted each other on agent names.
>
> The tier system in [`CLAUDE.md`](../CLAUDE.md) and the resourcing ladder in
> [`model-guide.md`](model-guide.md) apply to both harnesses. This file is the
> mechanics: what loads, what to delegate to, how to isolate, how to ship.
>
> Last reviewed: 2026-09-08.

## Start a session

Claude Code walks up to find `CLAUDE.md`, so it can start anywhere in the tree.

OMP reads project config from the current directory's `.omp/` only, and does not
walk up. Launch it from `/Users/jonyardley/Dev/intrada` or a worktree root, or
`.omp/config.yml` is silently ignored and the session starts on the wrong rung.

## What loads, and from where

| Thing | Path | Notes |
|---|---|---|
| Project rules | `CLAUDE.md` | Injected into every session and every subagent, verbatim |
| Repo settings and hooks | `.claude/settings.json` | Claude Code only. Permissions, plus the format-on-edit hook |
| OMP session roles | `.omp/config.yml` | OMP only. Pins the ladder so a session starts on the right rung |
| Sticky user rules | `~/.omp/agent/RULES.md` | OMP only. Re-attached near the current turn, survives long sessions |
| User profile | `~/.claude/CLAUDE.md` | Read directly by Claude Code; imported by `~/.omp/agent/AGENTS.md` for OMP |
| Task-scoped rules | `.claude/skills/*/SKILL.md` | Metadata only until read. Both harnesses discover these |
| Personal skills | `~/.claude/skills/*` | TDD, code review, worktrees, graphify |
| Subagents | `.claude/agents/*.md`, `~/.claude/agents/*.md`, `.omp/agents/*.md` | Do not cross harnesses. See Delegating |
| Xcode tools | `.mcp.json` | xcodebuildmcp, simulator workflow |

Skills cost one line of prompt until read, so reference-grade rules belong there
and only invariants belong in `CLAUDE.md`.

## Match ceremony to scope

The three tiers, the domain-sensitivity override and the two-PR rule are
normative in [`CLAUDE.md`](../CLAUDE.md) and are not restated here. In short:
Tier 1 ships without a plan, Tier 2 goes through plan mode, Tier 3 gets a short
spec that rides with the first implementation phase. If unsure, go one tier
lighter and drift up.

Tiers set the ceremony; [`model-guide.md`](model-guide.md) sets the resourcing:
which model and reasoning effort each kind of work runs on, and what a plan must
say about model, effort and parallel streams.

## How to brief an agent

- **State the goal, not the keystrokes.** "Users should be able to X" beats
  "edit file Y". The agent finds Y and checks it is the right place.

- **Name constraints up front** (must stay offline, no new dependencies, do not
  touch the bridge). Agents optimise to what you say matters.

- **Point at a reference** ("like the library list does it"). Reusing an
  existing pattern beats inventing a new one.

- **Give the tier if you have a strong view.** Otherwise the agent picks one and
  says which.

- **Expect one or two clarifying questions on anything architectural.** That is
  deliberate: it is cheaper than building the wrong thing.

## Delegating

**Agent definitions do not cross harnesses.** The frontmatter schemas are
incompatible, so `reviewer` and `test-runner` exist twice and their bodies have
to be kept in step by hand.

| Job | Claude Code | OMP |
|---|---|---|
| Read-only research | `Explore`, or `general-purpose` | `scout` |
| Mechanical, fully specified edits | `smol` | `sonic` |
| Conventional Tier 2 slice | `task` | `task` |
| Review a diff or a plan | `reviewer`, `advisor` | `reviewer`, `security-reviewer` |
| Run a gate and filter its log | `test-runner` | `test-runner` |
| Compressed repo context | (use `Explore`) | `librarian` |

Model pins live in the agent definition, not at the spawn. A definition with no
model inherits whatever the harness picks, which is how a mechanical sweep ends
up on the expensive model and a review ends up on a cheap one.

Four rules on top of the table:

- **One agent per vertical slice.** Core and iOS are one job, not two. Fan out
  only on genuinely independent pieces, and the lead integrates.

- **The reviewer is never weaker than the writer.** A pinned frontmatter model
  is beaten only by an explicit per-spawn override, never by the parent
  session's model, so a Fable session spawning `reviewer` gets Opus and reviews
  its own work with something weaker. Override it for that spawn, or keep the
  review in the strong session.

- **A cheap agent needs acceptance criteria that can fail tomorrow.** "Works" is
  not the bar. A `sonic` agent wiring a binary path passed every check it was
  given and hardcoded an ephemeral per-shell directory: true when checked, gone
  with the shell. The weakest reading of the criterion is the one you get.

- **A subagent's finding is a lead, not a fact.** Read-only research reports
  with the same confidence whether it observed something or inferred it. One on
  2026-09-04 blamed the wrong commit for a deletion, cited a line number
  pointing at a comment rather than the method it named, and said it could not
  run `git show` when it could. Brief them to mark observed against inferred,
  and verify anything you will act on.

**Gates run through `test-runner`, not in the lead session.** A passing suite
prints its counts and little else; a failing one prints thousands of lines, and
once that output is in the lead's transcript it is re-sent on every later turn.
`just check` and the `ios-test` tiers are the ones that bite. The exception is a
gate whose full output you need in order to act, which is rare enough to be
worth naming when you claim it.

Tell every fan-out task to skip `just check` and the test suites. Run gates
once, at the end, from the lead.

## Isolating concurrent work

Two or more branches in flight means separate working directories. Before
starting a second stream, read `skill://intrada-parallel-streams` for the
decoupled file set and the serialisation points.

`just worktree-new <name>` is the default. It branches from fresh `origin/main`
and seeds the warm `target/` and `ios/build` caches (#1205). Worktrees live at
`$INTRADA_WORKTREE_ROOT`, default `../intrada-worktrees`. Remove one with
`just worktree-rm <name>`, which also deletes its throwaway simulator.

OMP's `isolated: true` gives an APFS clone with its own `.git` instead. Measured
2026-09-04:

- carries `target/` (2.6 GB), so cargo starts warm

- does **not** carry `ios/build`, so an iOS build there is cold, 5 to 10 minutes

- being a clone rather than a worktree, it defeats the graphify hooks' worktree
  guard, so each commit kicks a full rebuild that is thrown away

Use `isolated: true` for the decoupled set and core-only Rust. Use
`just worktree-new` for anything touching `ios/`.

`graphify-out/` exists only in the main checkout, so Tier 1 work that wants the
knowledge graph stays there.

## Build and test control

The rules on driving iOS through the `just` recipes, on running `just check`
before pushing, and on the machine-global simulator are normative in
[`CLAUDE.md`](../CLAUDE.md). Beyond those:

- `just check` and `just ios-test` skip on an already-green HEAD. Delete
  `target/.check-stamp` or `ios/build/.ios-test-stamp` to force a run.

- `scripts/check-sim-free.sh` blocks a test run while another agent's simulator
  or `xcodebuild` is live, so only one stream runs iOS tests at a time. Stagger
  test-heavy tasks even when the code is independent.

- `just status` reads GitHub for what is in flight.

Simulator workflow, worktree isolation and the green-stamp skip in full:
[`ios-testing.md`](ios-testing.md).

## Guardrails already in place

You do not have to police these; they run whether an agent read the rules or not.

- **Format on edit.** `.claude/settings.json` runs `rustfmt` on every `.rs` file
  and `swift format` on every `.swift` file the agent writes, skipping
  `ios/generated/`. OMP's equivalent is `.omp/hooks/pre/format-on-edit.ts`.
  Hooks do not cross harnesses, and the hook only fires on new sessions, so run
  `just fmt` and `just ios-fmt` if unformatted code reaches CI.

- **Repo git hooks.** `scripts/install-git-hooks.sh` points `core.hooksPath` at
  `.githooks/`, and a Claude Code SessionStart hook runs it. The pre-push hook
  refuses a push to a merged-PR branch and flags comment bloat.

- **Dash check.** `scripts/check-dashes.sh` fails on em and en dashes in changed
  lines, in CI and pre-push. Bypass a justified case with `SKIP_DASH_CHECK=1`.

- **Permission deny list.** `.claude/settings.json` denies `gh pr merge`,
  `git push origin main`, `fly`, `just testflight` and the destructive simulator
  resets outright.

## Token control

Roughly, per session and again per subagent:

- `CLAUDE.md` is the fixed cost, paid on every request. Keep task-scoped rules
  in skills, which cost one line until read.

- A five-way fan-out pays the project rules five times, so prefer one capable
  agent over five when the work is not genuinely parallel.

- Read-only research agents return compressed context by design. Use them
  instead of reading file after file in the lead session.

- In OMP, `hideThinkingBlock` is display only. Lowering `defaultThinkingLevel`
  is what actually reduces reasoning tokens, and it costs correctness.

## Verification, the standard held

- UI changes: drive the simulator and show proof (screenshot or logs), **or**
  say explicitly "I cannot reach the running app, here is what you need to
  verify by hand". Never claim "all green" when that only means `cargo test`
  passed.

- Report failures faithfully with the actual output. No hedging, no "should
  work".

- Never report a gate as broken without making it fail. Break one assertion and
  watch it go red. Inferring breakage from silence costs more than a false
  green, because it sends work after a fault that was never there.

- After any push to an open PR, watch the run to a conclusion in the same turn
  and report it. Read the PR's mergeability, not just the job list: a renamed
  job leaves the old required context "expected" for ever, which is a hang
  rather than a failure and is invisible in the checks list (#1542).

## Shipping

The gate funnel, the Codecov expectations, the deferred-issue protocol and the
PR and issue body templates are all in `skill://intrada-shipping`, which binds
whether or not you loaded it. Read it before opening or updating a PR.

Two things are harness-specific rather than in the skill:

- **The self-review step.** In Claude Code that is the `ship` skill; in OMP it
  is the `reviewer` agent via `task`. Either way the review happens before a
  human looks.

- **Stacked PRs** are supported: open the child with base set to the parent's
  branch, depth 2 maximum. CI runs on stacked PRs because `ci.yml` has no branch
  filter on its `pull_request` trigger.

**Agents never merge.** A human reviews and merges.

## Code intelligence

Run `just lsp-setup` once per machine, and once per worktree that wants Swift.
Without it the LSP tooling answers nothing on either language, which pushes an
agent back onto grep for navigation and rename:

- `rust-analyzer` resolves on PATH as a rustup shim that fails unless the
  component is installed for the toolchain pinned in `rust-toolchain.toml`.

- `sourcekit-lsp` ships as a built-in and the binary is in Xcode's toolchain,
  but it never activates, because its root markers live under `ios/` and a
  session starts at the repo root. `.omp/lsp.json` adds `buildServer.json` as a
  marker; `just lsp-setup` writes that file.

`just lsp-setup` does more than write the build server, and the extra work is
the point. `xcode-build-server config` on its own aims the index at Xcode's
*default* DerivedData, which this repo never writes to, so sourcekit-lsp reports
`No such module` for UIKit and the generated packages: fabricated errors on code
that compiles, handed to an agent after every Swift edit. The recipe therefore
parses a real indexing build's log, which records per-file flags in `.compile`
and an `indexStorePath` in `buildServer.json`.

With that in place, diagnostics are honest, hover resolves, and
jump-to-definition works across files. `references` still returns nothing, which
is a sourcekit-lsp limitation here rather than a missing path, so finding the
callers of a Swift symbol stays a grep job.

## Worked examples

Both are real open issues, and both start the same way: claim the issue and stop
if a PR already exists.

```bash
gh pr list --repo jonyardley/intrada --state open --search "<N>"
gh issue view <N> --json closedByPullRequestsReferences
```

### Small: #1426, a hand-rolled primitive

`ReflectionSheet.swift` builds an eyebrow by hand with `kerning(1.2)` where the
`Eyebrow` primitive uses `tracking(1.5)`, so the sheet's labels are visibly
tighter than the twenty other eyebrows in the app, and the hand-roll drops
`Eyebrow`'s un-uppercased `accessibilityLabel`, so VoiceOver reads the shouty
version.

Tier 1. One file, no bridge, no schema, no auth, so no override applies.

1. One session, no plan mode, no subagents. Delegating a one-line change costs
   more than doing it. Sonnet 5 at `low` is the rung, but on a change this small
   the ceremony of moving there costs more than the tokens it saves.

2. `skill://intrada-design-system` binds here: reuse before creating, and never
   hand-roll something that exists. Read it before editing.

3. Replace the hand-roll with `Eyebrow`. Check the neighbouring `.badge`
   hand-roll on the same screen, and if it is a different primitive leave it and
   say so rather than widening the change silently.

4. Re-record the three affected references in one pass, then verify:
   ```bash
   just ios-snapshots-record ScreenSnapshotTests/testReflectionSheet
   just ios-fmt-check && just ios-test
   ```
   Recording is delete-then-run-twice by design, so a first-run failure is
   expected. Read the diff: the labels should get looser, not move.

5. Ship. Tier 1 trivia may skip the review subagent but still runs the gates.

Opener:

```text
Claim #1426 and stop if a PR already exists, then fix it.

Read skill://intrada-design-system first. ReflectionSheet.swift hand-rolls an
eyebrow at line 174; use the Eyebrow primitive instead. There is a second
hand-roll at line 87 on the badge font: that is a different primitive, so leave
it and flag it rather than widening this change.

Re-record the affected references with just ios-snapshots-record, then
just ios-fmt-check and just ios-test. Tell me which snapshots moved and why
before opening the PR.
```

### Larger: #1512, a bound the shell should not own

`ClickSheet.swift` hard-codes `2...12` and `EntrySettingsSheet.swift` hard-codes
`3...10`, both mirroring constants in `crates/intrada-core/src/validation.rs`.
When the core's bound moves, the sheet keeps offering the old range and starts
sending values the core rejects, and the write is refused with nothing on
screen. That is the swallowed-update failure the offline-first rules exist to
prevent.

Tier 2 on file count, but projecting a bound through the `ViewModel` changes the
bridge contract, so the domain-sensitivity override puts it up a tier.

1. Contract before code, at the top of the ladder: Fable 5 at `xhigh`. Pin the
   `ViewModel` shape first, in one session, and write it down before either side
   is wired. `max` is reserved for migrations.

2. This is a core plus iOS vertical slice, so **exactly one stream**. Do not fan
   out, and do not run a second agent against this repo while it is in flight.

3. Core PR first. TDD is the default for `intrada-core`: write the failing test,
   then project the bounds. Extend the Rust `assert_round_trips` helper to the
   new view type before any screen reads it, because a stub-bridge test cannot
   catch a bincode wire break (#846).

4. Get the core PR reviewed before starting the screens. On a multi-surface
   slice, one review at the end is too late to be cheap.

5. Screens PR second. Read both bounds from the `ViewModel`, delete both
   hard-coded ranges, and add the test the issue asks for: the offered range
   matches the core's, so widening the core cannot silently leave a sheet
   behind. A shell constant that merely repeats the number is not the fix.

6. Verify on the running app, not just in CI. Bindings regenerate through
   `_ios-sync`, but a core type change means iOS tests mean nothing until they
   have run `just ios-test-full`.

7. Ship as two PRs, core then screens, each independently reviewable.

Opener for the first session:

```text
Claim #1512 and stop if a PR already exists. Plan mode first, and do not
write code this session beyond the contract.

This changes the bridge contract, so use the strongest rung before you decide
anything. Pin the ViewModel shape that projects MIN_METRE_BEATS/MAX_METRE_BEATS
and the rep-target bound, and write it into the issue before either side is
wired. Read skill://intrada-offline-first: a refused write with nothing on
screen is the failure this exists to prevent.

This is a core plus iOS slice, so exactly one stream. Do not fan out.
Core PR only when we implement: TDD, and extend assert_round_trips for the new
view type before any screen reads it. Screens are a second PR after this one
is reviewed.
```

Opener for the screens session, once the core PR is reviewed:

```text
Screens half of #1512, core PR #<N> is merged. Read both bounds from the
ViewModel and delete the hard-coded 2...12 in ClickSheet.swift and 3...10 in
EntrySettingsSheet.swift. A shell constant repeating the number is not the fix.

Add the test the issue asks for: the offered range matches the core's, so
widening the core cannot silently leave a sheet behind. Then just ios-test-full,
because the core type changed. Re-record any snapshots the control changes
touch, and say which.
```

## What slows us down

- Vague approval of large scope ("do the rest") instead of finishing the current
  slice.

- Asking an agent to skip verification to save time. The rework costs more.

- Burying deferred work in PR descriptions rather than tracked issues.

- Pushing to `main`. Never; always a feature branch and a PR.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `.omp/config.yml` ignored | OMP session started below the repo root |
| A skill will not resolve | Skills are discovered at session start; restart after adding one |
| Model dropped mid-session | OMP prewalk armed; check for `--prewalk` |
| `just check` says already green | Stamp matches HEAD and the tree is clean; delete the stamp |
| Unformatted Swift or Rust reaching CI | Format hook only fires on new sessions; run `just fmt` and `just ios-fmt` |
| PR hangs on a check that never reports | A renamed job left its old required context "expected" (#1542) |
