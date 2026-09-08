# Model and effort guide

> Which Claude model and reasoning effort to use for each kind of work on
> intrada, and what every plan must say about them. Complements the tier system
> in [`CLAUDE.md`](../CLAUDE.md): tiers set the ceremony, this sets the
> resourcing.
>
> Last reviewed: 2026-09-08, against the Claude 5 family (Fable 5, Opus 5,
> Sonnet 5, Haiku 4.5). Re-review at the next model generation; pricing and
> effort semantics below were validated against the API docs on that date.
>
> The ladder is no longer prose only. `.omp/config.yml` pins the `default`,
> `plan`, `slow`, `task` and `advisor` roles to it, so an OMP session started in
> this repo begins on the right rung instead of re-deriving one, and
> `.omp/agents/*.md` pins a model per named subagent (see Subagents below).
> Session roles live in the config, per-agent pins live in the agent file, and a
> routing change usually means editing both.

## The organising rule

Match the **model** to how silently wrong the work can go, and the **effort**
to how much thinking beats typing. In this codebase the silent-failure surfaces
are the FFI bridge (positional bincode: wrong is a no-op, not a crash, #846),
local GRDB migrations (the device is the only copy of the user's data), the
`ActiveSession` crash-recovery blob (#1223, #1244, #1256), and auth. Those get
the strongest setup regardless of diff size. Everything else degrades
gracefully down the ladder because failure is visible: a wrong layout is caught
on the simulator, a wrong test fails in CI.

## The models

| Model | $/MTok in/out | Use for |
|-------|---------------|---------|
| Fable 5 | 10 / 50 | Unrecoverable-if-wrong work; direction-setting; the worst debugging |
| Opus 5 | 5 / 25 | Default for judgement-dense feature work and reviews |
| Sonnet 5 | 2 / 10 | Conventional coding on non-sensitive surfaces; near-Opus on coding |
| Haiku 4.5 | 1 / 5 | Search, explore, and report subagents (200K context) |

Prices are API list rates; on a subscription they still approximate relative
usage-limit weight. Two notable facts from the current docs:

- **Sonnet 5 reaches previously-Opus-tier quality on coding and agentic
  work.** The boundary between Sonnet and Opus is the *sensitivity of the
  surface*, not the size of the diff.
- **Fast mode (Opus only) is priced at 10/50, the same as Fable.** Use it when
  interactive latency genuinely matters; it is never an economy measure, and
  for sensitive work Fable at normal speed is usually better value.

## Effort

Five levels: `low`, `medium`, `high`, `xhigh`, `max`. Claude Code's default is
`xhigh`, which is also the documented sweet spot for coding and agentic work.

- **`xhigh`** — the default; leave it for coding and agentic sessions.
- **`high`** — planning conversations, docs, review synthesis.
- **`max`** — only when correctness beats cost outright: a migration touching
  shipped data, a blob-graph change. Can overthink routine work.
- **`low` / `medium`** — mechanical work, search subagents, test-runner
  agents. On Fable and Opus 5, `low` often outperforms prior generations at
  `xhigh`, which is why the rule below says drop effort before model.

## Coding

1. **Fable 5, xhigh (max for migrations)** — anything on the silent-failure
   list: bridge contract changes, GRDB migrations, the `ActiveSession` blob,
   auth. Also the worst debugging: bincode wire breaks, silent no-ops, "green
   but wrong" tests. This bug class got past Opus-era sessions three times.
2. **Opus 5, xhigh** — Tier 2 core work with real judgement (new events and
   handlers in `intrada-core`, TDD-first) and judgement-dense screens (a new
   flow with accessibility, SplitView, and snapshots built together).
3. **Sonnet 5, xhigh** — conventional Tier 2 on non-sensitive surfaces: a
   screen composed from existing primitives, an API endpoint on established
   conventions, iOS polish, docs and PR bodies. Cheap to verify visually or in
   CI, so a cheaper writer is fine.
4. **Sonnet 5 low, or Haiku 4.5** — Tier 1 trivia (typos, dep bumps, lint,
   snapshot re-records) and fan-out subagents that report facts back to a lead.

## Reviewing

**The reviewer is never weaker than the writer.** This mirrors Anthropic's own
advisor-pairing constraint (an advisor model must be at least as capable as
the executor it advises).

- Fable-written bridge or migration work: Fable reviews it.
- Ordinary Opus or Sonnet Tier 2: Opus reviews (the code-reviewer subagent).
- Small Tier 2 (one file, no sensitive surface): `/review` inline is enough.

## Subagents: the model belongs in the agent, not the spawn

The ladders above route a *session*. A lead also spawns *named agent types*, and
those get routed once, in the committed definition, rather than re-decided at
every spawn. A definition with no model inherits whatever the harness picks,
which is how a mechanical sweep ends up on the expensive model and a review ends
up on a cheap one. The routing below is by *job*, because the agent names differ
between Claude Code and OMP.

| Job (Claude Code · OMP) | Model + effort | Because |
|---|---|---|
| Read-only research (`Explore` · `scout`) | Haiku 4.5, low | Reports facts back to a lead. Never edits, so a wrong answer is caught by the lead verifying it |
| Mechanical, fully specified edits (`smol` · `sonic`) | Haiku 4.5, low (`smol`) · Sonnet 5, low (`sonic`) | Renames, sweeps, data collection. The decision is already made, so the cheapest rung that types accurately; the two pins differ and this row records both |
| Run a gate and filter its log (`test-runner` in both) | Sonnet 5, low | No judgement, and the gate itself is the check |
| Review a diff or a plan (`reviewer`, `advisor` · `reviewer`) | Opus 5, high | Judgement-dense, and bound by the never-weaker rule above. `high` matches the "review synthesis" rung, and matches `advisor` in `.omp/config.yml`, still pinned `claude-opus-5:high` |
| Conventional Tier 2 slice (`task` in both) | Sonnet 5, xhigh | Non-sensitive surface, patterns already in the repo |

Which named agent implements each job differs per harness, and the definitions
do not cross: see the Delegating table in
[`working-with-agents.md`](working-with-agents.md). Pin the model in the agent
definition rather than at the spawn.

**The never-weaker rule needs a lever on Fable work.** A pinned frontmatter
model is beaten only by `task.agentModelOverrides[<agent>]`, never by the parent
session's model, so a Fable session that spawns `reviewer` on a bridge or
migration diff gets Opus and reviews its own work with something weaker. Either
set `task.agentModelOverrides.reviewer` for that spawn, or keep the review in
the Fable session.

Four rules on top of the table:

- **A cheap agent needs acceptance criteria that can fail.** "Works" is not the
  bar. A `sonic` agent wiring a binary path passed every check it was given and
  hardcoded an ephemeral per-shell directory: true when checked, gone with the
  shell. The weakest reading of the criterion is the one you get.
- **Read-only research is always the cheap rung**, and its output is a lead
  rather than a fact (see Rules of thumb). Paying more does not fix that;
  verifying before acting does.
- **The sensitivity override applies here too.** A subagent touching the bridge,
  a migration, the `ActiveSession` blob or auth goes up a rung, or the lead keeps
  that slice itself.
- **Gates run through `test-runner`, not in the lead session.** A passing suite
  prints its counts and little else; a failing one prints thousands of lines,
  and once that output is in the lead's transcript it is re-sent on every later
  turn. `just check` and the `ios-test` tiers are the ones that bite. The
  exception is a gate whose full output you need in order to act, which is rare
  enough to be worth naming when you claim it.

## Planning

1. **Fable 5, high** — direction: roadmap pivots, reversals, "should we build
   this at all", and Tier 3 specs. A wrong call here costs weeks, so this is
   the clearest Fable case in the guide.
2. **Opus 5, high** — slice planning inside a settled direction: claim checks,
   serialisation points, decomposition, Plan mode before Tier 2 work.
3. **Sonnet 5, medium** — plan mechanics: turning an agreed plan into GitHub
   issues, writing handover openers.

**Plan on a stronger model than you implement on.** An Opus plan executed by
Sonnet beats Sonnet planning for Sonnet: the plan is where errors are cheapest
to catch and most expensive to miss.

## Design: technical vs visual

**Technical design fails silently; visual design fails visibly.** A wrong
bridge contract ships and corrupts quietly; a wrong layout is caught the
moment you look at the simulator. So technical design tops out at Fable with
no Sonnet tier, while visual work degrades gracefully.

### Technical design (contracts, data model, boundaries)

- **Fable 5, high** — the Event/Effect/ViewModel shape for a slice ("contract
  before code"), anything crossing the bincode bridge, schema and migration
  strategy, sync and reconciliation boundaries. Tier 3 specs live here.
- **Opus 5, high** — design within a settled contract: handler decomposition,
  where a shared primitive gets extracted, test strategy for a slice.
- No Sonnet tier. Technical design light enough for Sonnet is really
  implementation; route it through the coding ladder instead.

### Visual/UX design (how the app looks, feels, flows)

- **Fable 5 or Opus 5, high** — UX decisions: a new flow or surface judged
  against [`design-principles.md`](design-principles.md), anything adding a
  T-numbered decision, deliberate redesigns changing `Theme.swift` tokens.
- **Opus 5, high** — visual application: mocking screens in Claude Design
  from the existing kit, composing known primitives into a new layout.
- **Sonnet 5, medium** — design bookkeeping: re-exports, `support.js` sync,
  appending already-made decisions to the log.

When one task contains both (a new screen needing a new event), split it:
contract first at the top of the ladder, pixels second lower down. That is the
two-PR rule wearing a different hat.

## Plans ship their own resourcing

Every plan (slice plan, spec phase breakdown, handover) names, per task:

1. **Model + effort** — using the ladders above. A plan that says "then build
   the screen" without "Sonnet 5, xhigh" forces the next session to re-derive
   the routing, or default upward to the expensive model.
2. **Where it runs** — this session, a new session, or a subagent; one fresh
   session per task unless stated.
3. **Parallel streams** — which tasks run concurrently and which serialise:
   - At most one core+iOS vertical stream; a second stream only in the
     decoupled set (`intrada-api`, `docs/`, `specs/`, `design/`, CI/tooling).
   - Flag serialisation points explicitly (`app.rs`, `session.rs`,
     `ScreenSnapshotTests.swift`, `PreviewSupport.swift`, `project.yml`,
     `Cargo.lock`). If two tasks touch one, the plan says "B after A".
   - The simulator is machine-global: only one stream runs iOS tests at a
     time, so stagger test-heavy tasks even when the code is independent.

The savings from routing and the speed from parallelism only happen if the
plan encodes them. Sessions picking their own model default upward; sessions
discovering a file collision mid-flight burn a rebase plus a re-run of every
gate, which costs more than the parallelism saved. One planning session at
Opus or Fable prices, spent deciding routing once, is what lets several
execution sessions run cheap.

**A plan without model, effort, and stream annotations is incomplete**, the
same way a phase without a test plan is.

## Rules of thumb

- **The sensitivity override applies to models too.** Auth, bridge, schema,
  and migration work jumps a model-and-effort level, whatever the file count.
- **Drop effort before dropping model.** A capable model at `low` beats a
  small model thinking hard about something it will get subtly wrong, and the
  current generation's `low` often outperforms the last generation's `xhigh`.
- **Fable turns run long.** Single requests on hard tasks can take many
  minutes at high effort. Use it where deliberation pays; do not park it on
  interactive back-and-forth.
- **Decisions go up the ladder, execution goes down it.** If a session will
  choose between hard-to-reverse options, go up; if it applies a choice
  already made, go down.
- **A subagent's finding is a lead, not a fact.** A read-only scout reports
  with the same confidence whether it observed something or inferred it. One
  on 2026-09-04 blamed the wrong commit for a deletion, cited a line number
  that pointed at a comment rather than the method it named, and said it could
  not run `git show` when it could; every conclusion drawn from it was wrong.
  Brief them to mark observed against inferred, and verify anything you will
  act on before acting. Cheapest on archaeology, where the answer is one
  `git log -S` you can run yourself.
- **Prewalk hands work down; it does not think harder.** It switches the
  session to the `@smol` role after the first `edit` or `write` following a
  `todo` call, and the switch is sticky for the rest of that session. So it
  belongs at the start of a session whose only job is executing a finished
  plan, and a plan routing a task that way says so explicitly. Armed
  mid-conversation it either does nothing, because no `todo` call fires, or it
  hands every remaining decision to the cheap model. For "decide here, execute
  cheaply", use a subagent instead: the deciding session stays strong.
