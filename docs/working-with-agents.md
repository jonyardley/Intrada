# Working with Claude Code on intrada

> The mechanics of driving this repo from Claude Code: what loads and what it
> costs, the layers a rule can live in, model and effort per activity, what a
> plan must say, delegation, isolation, guardrails and worked examples. The tier
> system in [`CLAUDE.md`](../CLAUDE.md) is normative and not restated. This
> file replaced the OMP-era guides and `model-guide.md` on 2026-09-08; why OMP
> was retired is in [`reference.md`](reference.md).
>
> Last reviewed: 2026-09-13, against the Claude 5 family (Fable 5.1, Opus 5,
> Sonnet 5, Haiku 4.5). Re-review at the next model generation.

## What loads, and what it costs

A session pays a fixed context bill before the first word, and a subagent pays
most of it again. Everything in the first column below is in that bill.

| Input | Path | When it loads |
|---|---|---|
| Project rules | `CLAUDE.md` | Every session and every subagent, in full. Under 200 lines by rule |
| Path-scoped rules | `.claude/rules/*.md` | When a file matching the rule's `paths:` globs is read with the Read tool. A `cat` through Bash does not count. They reload the same way after compaction |
| Skills | `.claude/skills/*/SKILL.md` | The description every session; the body when invoked by name (`/ship`, `/intrada-parallel-streams`) |
| Agents | `.claude/agents/*.md` | The description every session; the body becomes the subagent's system prompt |
| Repo settings | `.claude/settings.json` | The model and effort a session opens on (Sonnet 5 medium, 1M window), permissions, the format-on-edit and git-hook-install hooks, and the plugins switched off for this repo |
| User rules | `~/.claude/CLAUDE.md`, `~/.claude/rules/` | Every session, before the project rules; project wins on conflict |
| Auto memory | `~/.claude/projects/<project>/memory/MEMORY.md` | Every session, first 200 lines. Not loaded into subagents. The one input that can carry a stale fact |
| User hooks | `~/.claude/settings.json`, `~/.claude/hooks/` | Text injected on every prompt (the turn reminder, and the context watch past 250k), after a push (the CI-watch note) and in the day's first session (one usage line); the bash guard runs before every command, the spawn guard before every subagent |
| Plugins | `enabledPlugins` in user settings | Each plugin skill's description, every session. `.claude/settings.json` switches slack, atlassian, visual-explainer and frontend-design off here |
| Xcode tools | `.mcp.json` | xcodebuildmcp and the simulator workflow |

Run `/context` in a session to see exactly which files loaded.

## The layers, and which one a rule belongs in

A rule lives in exactly one of these, chosen by who reads it and when.

1. **Gates.** Branch protection, `permissions.deny`, the bash guard, CI, the git
   hooks. Enforced whether or not anyone read a rule, so the prose comes out in
   the same change that adds the gate. The comment density check, the dash
   check and the simulator lock are the models.
2. **`CLAUDE.md`.** Invariants every session needs: architecture, the tier
   system, the Always list. Paid on every request, so it stays under 200 lines.
3. **Path-scoped rules.** Offline-first, the UI and tone rules, the per-screen
   quality bar and the silent-failure hazards. Free until a covered file is
   read, then in context for the rest of the session.
4. **Skills, by name.** Workflows rather than surfaces: shipping and parallel
   streams. `/ship` is the pre-push funnel.
5. **Agents.** `reviewer`, `test-runner`, `smol`, `task`, plus the built-in
   `Explore`. Model and effort pinned in the definition.
6. **Hooks.** Repo: format on edit, install the git hooks. User: the bash
   guard, the spawn guard, the per-prompt reminder and context watch, the
   post-push CI note, the daily usage line.
7. **Auto memory.** What neither CLAUDE.md records: preferences, corrections,
   project state the code cannot show.
8. **Docs on demand.** `reference.md` for the why behind every rule, the specs,
   the roadmap. Cost nothing per turn.

The test for the personal versus project split, from the RIBA template review:
if this is set wrong, who does it hurt? Only the author, and it is personal
(`.claude/settings.local.json`, `~/.claude`). Anyone else, and it is project,
checked in, and enforced somewhere the personal layer cannot weaken it.

## Model and effort

Match the **model** to how silently wrong the work can go, and the **effort** to
how much thinking beats typing. The silent-failure surfaces here are the FFI
bridge (positional bincode: wrong is a no-op, not a crash, #846), local GRDB
migrations (the device is the only copy of the user's data), the `ActiveSession`
crash-recovery blob (#1223, #1244, #1256) and auth. Those get the strongest
setup regardless of diff size. Everything else degrades gracefully because
failure is visible: a wrong layout is caught on the simulator, a wrong test
fails in CI.

| Model | $/MTok in/out | Use for |
|---|---|---|
| Fable 5.1 | 10 / 50 | Unrecoverable-if-wrong work; direction-setting; the worst debugging |
| Opus 5 | 5 / 25 | Default for judgement-dense feature work and reviews |
| Sonnet 5 | 2 / 10 | Conventional coding on non-sensitive surfaces; near-Opus on coding |
| Haiku 4.5 | 1 / 5 | Search, explore and report subagents |

Effort has five levels: `low`, `medium`, `high`, `xhigh`, `max`. This repo
opens at `medium`, and effort does not follow a model switch, so a session
that climbs the ladder sets `/effort` as well as `/model`. `xhigh` is the
documented sweet spot for lead-session coding on judgement-dense work; `high`
for patterned coding, planning, docs and review synthesis; `max` only when correctness beats cost
outright (a migration touching shipped data, a blob-graph change), since it can
overthink routine work; `low` and `medium` for mechanical work and gate
runners. `/model` and `/effort` change the running session, and both persist
to settings unless chosen as session-only. Fast mode (Opus only) is priced at
Fable's rate: use it when interactive latency genuinely matters, never as an
economy measure, and for sensitive work Fable at normal speed is better value.

**Coding**

1. **Fable 5.1, xhigh** (`max` for migrations): anything on the silent-failure
   list, and the worst debugging (bincode wire breaks, silent no-ops, "green
   but wrong" tests). This bug class got past Opus-era sessions three times.
2. **Opus 5, xhigh**: Tier 2 core work with real judgement (new events and
   handlers in `intrada-core`, TDD-first) and judgement-dense screens.
3. **Sonnet 5, high**: conventional Tier 2 on non-sensitive surfaces: a screen
   from existing primitives, an endpoint on established conventions, iOS
   polish, docs and PR bodies.
4. **Sonnet 5 low, or Haiku 4.5**: Tier 1 trivia and fan-out subagents that
   report facts back.

**Planning.** Fable 5.1 high for direction (roadmap pivots, reversals, "should
we build this at all", Tier 3 specs). Opus 5 high for slice planning inside a
settled direction. Sonnet 5 medium for plan mechanics: issues from an agreed
plan, handover openers. Plan on a stronger model than you implement on.

**Design.** Technical design fails silently, visual design fails visibly.
Contracts, data model and boundaries: Fable 5.1 high for the
Event/Effect/ViewModel shape, anything crossing the bridge, and schema
strategy; Opus 5 high within a settled contract; no Sonnet tier. Visual and UX:
Fable or Opus at high for a new flow judged against `design-principles.md` or
a T-numbered decision; Opus 5 high for mocking screens in Claude Design; Sonnet
5 medium for design bookkeeping. A task with both halves splits, contract first
at the top of the ladder: the two-PR rule wearing a different hat.

**Reviewing.** The reviewer is never weaker than the writer. Fable-written
bridge or migration work gets a Fable review: keep the review in the Fable
session, or spawn `reviewer` with the Agent tool's `model` parameter set to
Fable, which is the one lever that beats a definition's pin. Ordinary Tier 2
gets `reviewer`; a small Tier 2 on one file with no sensitive surface can take
`/code-review` inline (the code-review plugin skill, not a repo command).

**Rules of thumb.** The sensitivity override applies to models: auth, bridge,
schema and migration work jumps a model-and-effort level whatever the file
count. Drop effort before dropping model. Fable turns run long, so use it where
deliberation pays, not on interactive back-and-forth. Decisions go up the
ladder, execution goes down it. A subagent's finding is a lead, not a fact: one
on 2026-09-04 blamed the wrong commit, cited a line that pointed at a comment,
and said it could not run `git show` when it could. Brief research agents to
mark observed against inferred, and verify before acting.

**What it costs in practice.** Measured over the fortnight to 2026-09-13 from
the session transcripts on Jon's machine, all projects, weighted at API prices;
`just usage 14` prints the same table. Bullets naming a week come from
`just usage`, whose default window is seven days.

- **Context length drives usage more than the rung.** 52 of 154 main sessions
  passed 200k tokens, and the eight biggest sessions were 36% of the fortnight.
  `/compact` when mid-task. The status line shows the context in thousands,
  amber from 200k and red from 250k.
- **A parked session pays again.** The prompt cache lasts an hour; the first
  turn after a longer gap re-sends a context past 50k at write price. In the
  week to 2026-09-13 that was 194 turns and $233, and cache writes were 29% of
  that week's spend. The context watch names such a turn as it happens: finish
  the unit and `/clear` in the same sitting rather than leave a session to come
  back to.
- **Tool output is what fills the context.** 36 MB in the week to 2026-09-13,
  Read 31%, then git, sed, grep, just and cat at 5 to 10% each; `just usage`
  prints the table. Read once, keep ranges tight, and run gates in
  `test-runner`.
- **Per main-session turn**: Fable 5.1 high $0.20 (xhigh $0.32), Opus 5 high
  or medium $0.15, Sonnet 5 medium $0.05. Fable's cache reads cost $0.25 per
  MTok against Opus's $0.50, which keeps the gap to Opus small at long context;
  dropping to Sonnet is what saves. This repo's `.claude/settings.json` opens
  sessions on Sonnet 5 medium with the 1M window, so name the rung the ladders
  above give the task and switch with `/model` and `/effort` before the work
  starts, saying so, not after.
- **Subagents were 26% of the fortnight's usage.** Their largest line was
  `task` spawned with `model: opus` over its Sonnet pin: keep the judgement in the lead and hand
  down settled work instead of lifting the agent. `task` runs grow as long as
  main sessions (59% of their turns past 200k), so brief one slice per spawn.

## Plans ship their own resourcing

Every plan (slice plan, spec phase breakdown, handover) names, per task:

1. **Model and effort**, from the ladders above. "Then build the screen" without
   "Sonnet 5, high" forces the next session to re-derive the routing, or
   default upward.
2. **Where it runs**: this session, a new session, or a subagent; one fresh
   session per task unless stated.
3. **Parallel streams**: one stream touching `crates/intrada-core` or
   `crates/intrada-ffi`, plus any number of shell-only streams that touch only
   `ios/` and no crate and have named the screens they own; serialisation
   points named explicitly ("B after A"); one stream running iOS tests at a
   time, which costs little to queue behind (a fast-tier run is well under a
   minute either way, #1621).

A plan without model, effort and stream annotations is incomplete, the same way
a phase without a test plan is.

## Delegating

| Job | Agent | Pinned | Because |
|---|---|---|---|
| Read-only research | `Explore` (built-in) | Pass `model: haiku` at the spawn; it has no definition to pin, and the spawn carries no effort setting | Reports facts back; a wrong answer is caught by the lead verifying it |
| Mechanical, fully specified edits | `smol` | Haiku 4.5, low | The decision is already made; the cheapest rung that types accurately |
| Run a gate and filter its log | `test-runner` | Sonnet 5, low | No judgement; the gate itself is the check |
| Review a diff or a plan | `reviewer` | Opus 5, high | Judgement-dense; never weaker than the writer |
| Conventional Tier 2 slice | `task` | Sonnet 5, high | Non-sensitive surface, patterns already in the repo |

All four definitions live in `.claude/agents/`, so they are reviewed like code
and travel with the checkout. Pin model and effort in the definition rather than
at the spawn; the two exceptions are `Explore`, which has no definition, and
lifting `reviewer` to Fable for Fable-written work.

`task` sits at high, not xhigh: the effort premium buys little on work that
follows a pattern already in the repo, and over the fortnight to 2026-09-13
context length dominated its cost either way (59% of its turns past 200k).

Four rules on top:

- **One agent per vertical slice.** Core and iOS are one job. Fan out only on
  genuinely independent pieces, and the lead integrates
  (`.claude/skills/intrada-parallel-streams/SKILL.md`).
- **A cheap agent needs acceptance criteria that can fail** tomorrow, not just
  now. A mechanical-edit agent once wired a binary path to a per-shell
  directory that was gone with the shell; every criterion it was given was
  true at the moment of checking.
- **The sensitivity override applies to subagents.** One touching the bridge, a
  migration, the blob or auth goes up a rung, or the lead keeps that slice.
- **Gates run through `test-runner`, never in the lead.** A failing suite
  prints thousands of lines that are re-sent on every later turn. Tell every
  fan-out task to skip `just check` and the suites; run them once, at the end.

## Isolating concurrent work

Every session that edits starts in its own worktree, whether or not another is
running (CLAUDE.md, Always step 3). Before a second stream, read `.claude/skills/intrada-parallel-streams/SKILL.md` for the
decoupled file set and the serialisation points.

`just worktree-new <name>` branches from fresh `origin/main` and seeds the warm
`target/` and `ios/build` caches (#1205). Worktrees live at
`$INTRADA_WORKTREE_ROOT`, default `../intrada-worktrees`. `just worktree-rm
<name>` removes one and deletes its throwaway simulator. `graphify-out/` exists
only in the main checkout: query it there by path from a worktree
(`docs/reference.md`), never move the work there. Once you have a worktree,
edit only inside it.

`just worktrees` lists every worktree with its branch, uncommitted file count
and the session that holds its lease. Read it before touching a worktree you did
not create: a clean tree at main is not evidence that it is free. What the lease
claims, when it is taken and released, and what the guard allows in each of the
three places a session can be, are all in [`docs/worktrees.md`](worktrees.md).
In short: main lets anyone read and build but nobody edit, your own worktree is
yours entirely, and someone else's is readable and nothing more.

Run from a cmux terminal, `just worktree-new` prints the `cmux new-workspace`
command for the new worktree, because the sidebar shows the branch and PR of the
directory a session started in. It never starts a session itself (#1720): which
client you work in is your choice, not the recipe's.
`INTRADA_WORKTREE_CMUX=0` silences the suggestion.

**A session in the main checkout can drive a worktree without restarting**, from
2026-09-12. Starting in the worktree stays the default, because the path-scoped
rules in `.claude/rules/` load only under the directory a session started in. A
session already running does not get them by cd-ing: it reads the rules for the
files it is about to touch by hand, or it is working blind.

The mechanism is the `cd` prefix, and the `EnterWorktree` tool is still banned
here: it marks the session isolated and the bash guard then refuses every
version control command, so that session can never commit. Create the worktree
and prefix each shell command instead. The exact shape the prefix must take, and
what happens on a machine whose hooks predate all this, are in
[`docs/worktrees.md`](worktrees.md).

## Build and test control

The rules on driving iOS through the `just` recipes, running `just check`
before pushing, and the machine-global simulator are in `CLAUDE.md`. Beyond
those: `just check` and `just ios-test` skip on an already-green HEAD (delete
`target/.check-stamp` or `ios/build/.ios-test-stamp` to force a run);
`scripts/ios-sim-lock.sh` serialises `just ios-test`/`ios-test-full` runs
machine-wide, waiting rather than refusing while another agent's run holds it
(#1622), and each run shuts down the sim it booted when it finishes; `just
status` reads GitHub for what is in flight.
Simulator workflow in full: [`ios-testing.md`](ios-testing.md).

## Guardrails already in place

These run whether or not an agent read the rules.

- **Format on edit.** `.claude/settings.json` runs `rustfmt` on every `.rs` and
  `swift format` on every `.swift` the agent writes, skipping `ios/generated/`.
  Hooks load at session start, so run `just fmt` and `just ios-fmt` if
  unformatted code reaches CI.
- **Repo git hooks.** `scripts/install-git-hooks.sh` points `core.hooksPath` at
  `.githooks/`, run by a SessionStart hook. Pre-push refuses a push to a
  merged-PR branch and runs the comment-density and dash checks.
- **Dash check.** `scripts/check-dashes.sh` fails on em and en dashes in changed
  lines, in CI and pre-push. `SKIP_DASH_CHECK=1` for a justified case.
- **Link check.** `scripts/check-links.sh` fails on a markdown link added to a
  path that does not exist, and on a file the branch renames or deletes that
  something still links to, in `just hygiene` and CI. It reads the working
  tree, so an uncommitted link counts; the first half reads changed lines only,
  so a link already broken in a file nobody touched still ships. External URLs
  are skipped. `SKIP_LINK_CHECK=1` for a justified case.
- **Release name check.** `scripts/check-release-name.sh` fails when the app and
  the TestFlight lane stop composing the same Sentry release name, which would
  otherwise show up only as crashes filed under a release nobody created.
- **Permission deny list.** `.claude/settings.json` denies `gh pr merge`,
  `git push origin main`, `fly`, `just testflight` and the destructive
  simulator resets outright. Branch protection on `main` backs the first two
  server-side.
- **On Jon's machine, not in the repo**: `~/.claude/hooks/guard-bash.sh`
  matches the same denials inside compound commands, the turn reminder
  re-attaches the style rules on every prompt, and the post-push hook restates
  the CI-watch rule after every push. `guard-spawn.sh` refuses a spawn that
  lifts a subagent above the model in its definition (`reviewer` excepted, per
  Reviewing above), `context-watch.sh` says to `/clear` or `/compact` once a
  session passes 250k and again at 400k, and `usage-daily.sh` opens the first
  session of each day with one line from `usage-report.py`.

## Session controls

| Want | Do |
|---|---|
| The pre-push funnel | `/ship`: gates through `test-runner`, then `reviewer`, then the PR |
| Review the current diff | `/code-review` (the code-review plugin skill), at a chosen depth. Say "comment-policy violations are Blockers" or they survive as nits |
| Change rung mid-session | `/model`, `/effort`. Both persist unless chosen as session-only |
| See what loaded | `/context` lists the memory files and rules in this session |
| See what sessions cost | `just usage` (last 7 days by agent, model and effort, plus the biggest sessions); `just usage 14` for a fortnight |
| Edit the rules files | `/memory` |
| Tidy up permission prompts | `/fewer-permission-prompts` |

The **Superpowers plugin is disabled**, deliberately: its "invoke a skill for
anything" posture fights the tier system. Four of its skills were kept as
standalone globals: `test-driven-development`, `requesting-code-review`,
`receiving-code-review` and `using-git-worktrees`. `/speckit-*` is deprecated.

## Verification, the standard held

- UI changes: drive the simulator and show proof, or say explicitly "I cannot
  reach the running app, here is what you need to verify by hand". Never claim
  "all green" when that means `cargo test` passed.
- Report failures faithfully with the actual output. No "should work".
- Never report a gate as broken without making it fail.
- After any push to an open PR, watch the run to a conclusion in the same turn.
  Read the PR's mergeability, not just the job list: a renamed job leaves the
  old required context "expected" for ever, which is a hang, not a failure,
  and is invisible in the checks list (#1542).

## Shipping

The gate funnel, Codecov expectations, the deferred-issue protocol and the PR
and issue body templates are in `.claude/skills/intrada-shipping/SKILL.md`,
which `/ship` follows. Stacked PRs are supported: open the child with base set
to the parent's branch, depth 2 maximum; CI runs on them because `ci.yml` has
no branch filter on `pull_request`. **Agents never merge.**

## Code intelligence

Run `just lsp-setup` once per machine, and once per worktree that wants Swift.
Without it neither LSP answers anything: `rust-analyzer` on PATH is a rustup
shim that fails unless the component is installed for the pinned toolchain, and
`sourcekit-lsp` never activates because its root markers live under `ios/`
while a session starts at the repo root. The recipe also does more than write
the build server: `xcode-build-server config` alone aims the index at Xcode's
default DerivedData, which this repo never writes to, so sourcekit-lsp reports
`No such module` on code that compiles. The recipe parses a real indexing
build's log instead, so diagnostics are honest, hover resolves and
jump-to-definition works across files. `references` still returns nothing,
which is a sourcekit-lsp limitation, so finding the callers of a Swift symbol
stays a grep job.

## Worked examples

Both are real issues and both start the same way: claim the issue and stop if
a PR already exists.

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

1. One session, no plan mode, no subagents. Sonnet 5 at `low` is the rung, but
   on a change this small the ceremony of moving there costs more than it saves.
2. Reading the file loads `.claude/rules/ios-ui.md`: reuse before creating,
   never hand-roll something that exists.
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
5. Ship. Tier 1 trivia may skip the review agent but still runs the gates.

Opener:

```text
Claim #1426 and stop if a PR already exists, then fix it.

ReflectionSheet.swift hand-rolls an eyebrow at line 174; use the Eyebrow
primitive instead. There is a second hand-roll at line 87 on the badge font:
that is a different primitive, so leave it and flag it rather than widening
this change.

Re-record the affected references with just ios-snapshots-record, then
just ios-fmt-check and just ios-test. Tell me which snapshots moved and why
before opening the PR.
```

### Larger: #1512, a bound the shell should not own

`ClickSheet.swift` hard-codes `2...12` and `EntrySettingsSheet.swift` hard-codes
`3...10`, both mirroring constants in `crates/intrada-core/src/validation.rs`.
When the core's bound moves, the sheet keeps offering the old range and starts
sending values the core rejects, and the write is refused with nothing on
screen. That is the swallowed-update failure the offline-first rule exists to
prevent.

Tier 2 on file count, but projecting a bound through the `ViewModel` changes the
bridge contract, so the domain-sensitivity override puts it up a tier.

1. Contract before code, at the top of the ladder: Fable 5.1 at `xhigh`. Pin
   the `ViewModel` shape first, in one session, and write it down before either
   side is wired. `max` is reserved for migrations.
2. This touches `crates/`, so it is the one crate-touching stream this repo
   allows at a time. Do not fan out, and do not start a second stream that
   touches `crates/` while it is in flight; a shell-only stream elsewhere that
   has named its own screens may still run.
3. Core PR first. TDD is the default for `intrada-core`: write the failing test,
   then project the bounds. Extend the Rust `assert_round_trips` helper to the
   new view type before any screen reads it, because a stub-bridge test cannot
   catch a bincode wire break (#846).
4. Get the core PR reviewed before starting the screens. On a multi-surface
   slice, one review at the end is too late to be cheap.
5. Screens PR second. Read both bounds from the `ViewModel`, delete both
   hard-coded ranges, and add the test the issue asks for: the offered range
   matches the core's. A shell constant that merely repeats the number is not
   the fix.
6. Verify on the running app, not just in CI. A core type change means iOS
   tests mean nothing until `just ios-test-full` has run.
7. Ship as two PRs, core then screens, each independently reviewable.

Opener for the first session:

```text
Claim #1512 and stop if a PR already exists. Plan mode first, and do not
write code this session beyond the contract.

This changes the bridge contract, so use the strongest rung before you decide
anything. Pin the ViewModel shape that projects MIN_METRE_BEATS/MAX_METRE_BEATS
and the rep-target bound, and write it into the issue before either side is
wired. A refused write with nothing on screen is the failure the offline-first
rule exists to prevent.

This touches crates/, so it is the one crate-touching stream running. Do not
fan out, and do not start a second stream that touches crates/ while this is
in flight. Core PR only when we implement: TDD, and extend assert_round_trips
for the new view type before any screen reads it. Screens are a second PR
after this one is reviewed.
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
| A rule did not load | Rules with `paths:` fire on the Read tool only; a `cat` via Bash does not count. `/context` shows what loaded |
| A skill will not resolve | Skills are discovered at session start; restart after adding one |
| `just check` says already green | Stamp matches HEAD and the tree is clean; delete the stamp |
| Unformatted Swift or Rust reaching CI | The format hook loads at session start; run `just fmt` and `just ios-fmt` |
| PR hangs on a check that never reports | A renamed job left its old required context "expected" (#1542) |
| A subagent ran on the wrong model | Its definition has no `model:` or `effort:` pin, so it inherited the session's |
