# Phase R — the post-revert consolidation and rethink plan

*Agreed 2026-08-14. This is the working plan for the phase that follows the
coach revert (#1344): audit the restored builder, design and implement the
improvements, and choose the next major direction through research-backed,
iterative decision making. Which step is live is whichever issue carries an
open PR; when this doc and the issues disagree, the issues are right.*

*Phase R closed 2026-09-09 (#1615). The stream rules below predate the
current ones in `.claude/skills/intrada-parallel-streams/SKILL.md`, revised
by #1623: that file is the live rule, this is a historical record.*

## Ground rules for the whole phase

- **API is descoped.** `crates/intrada-api` gets compile-keeping fixes only.
  No audit findings, no design work, no feature work there this phase.
- **Every step names its model, effort and run location** before it starts.
  Defaults: Fable 5 high for synthesis and judgement, Sonnet 5 medium for
  mechanical or well-templated work.
- **Iterative, not wholesale.** Every slice shipped is independently valuable
  and cheaply reversible. That is the anti-coach-pivot discipline.
- Agreed plans with work in them become GitHub issues immediately, sized and
  labelled. PR descriptions are not tracking.
- One core+iOS vertical stream at a time; a second stream only in the
  decoupled set (docs, CI, design). The simulator is machine-global: one iOS
  test runner at a time.

## Stage 1 — Audit (2-3 sessions, ~2 days elapsed)

Three independent sweeps, then one synthesis. Output:
`docs/audit-2026-08.md` (prioritised findings) plus a cleaned issue board.

| Step | What | Model / effort | Where | Parallel with |
|------|------|----------------|-------|---------------|
| 1.1 | Code-health audit via the `improve` skill: core, ffi, ios. Correctness, coach leftovers, offline-first invariant violations, design-system drift, test-coverage gaps. Read-only, findings only. | Fable 5 high (lead); fans out ≤4 Explore subagents | Lead session; subagents in-process | 1.2, 1.3 |
| 1.2 | Product walk-through: drive the app on the simulator through each journey in `docs/journeys.md`, screenshot per screen, record friction. The builder has not been used critically since the revert. | Fable 5 high (needs vision + judgement) | Lead session, after 1.1's subagents return (sim is global, keep it serial) | 1.3 |
| 1.3 | Issue triage: all ~40 open issues re-checked against post-revert reality. Coach-tainted or stale ones (#1346, #1082, #1104 at minimum) closed, re-scoped or re-labelled. | Sonnet 5 medium (mechanical cross-check) | Separate session or subagent | 1.1, 1.2 |
| 1.4 | Synthesis: merge the three sweeps into `docs/audit-2026-08.md`, ranked by leverage. Open issues for everything actionable. | Fable 5 high | Lead session | Nothing (waits on 1.1-1.3) |

## Stage 2 — Design the improvements (2-3 days, overlaps Stage 1's tail)

| Step | What | Model / effort | Where | Parallel with |
|------|------|----------------|-------|---------------|
| 2.1 | Partition audit findings: UI-shaped vs not. Non-UI items skip straight to Stage 3 issues. | Fable 5 high | Lead session | — |
| 2.2 | Claude Design mocks for UI-shaped findings, against the existing kit. Decisions appended to the design-principles log. **Blocked on the Claude Design account sort-out (2026-08-07 hold)** unless Jon lifts it. | Fable 5 high | Claude Design project | 2.3 |
| 2.3 | Write the sized, labelled GitHub issues for all improvement work, with dependency order. | Sonnet 5 medium | Separate session or subagent | 2.2 |

## Stage 3 — Implement (1-2 weeks)

Work the Stage 2 issue list strictly by tier (CLAUDE.md Workflow). Standing
debt items #1348 (shell-dead `Set` domain) and #1345 (wire-pin port to the
`ActiveSession` blob) are in scope regardless of what the audit finds.

- **Vertical stream** (core + iOS): one at a time, one worktree, TDD by
  default for core changes. Fable 5 high for bridge/domain work; Sonnet 5
  medium for Tier 1 and well-templated Tier 2 screens.
- **Decoupled stream** (docs, CI, design tokens): may run in parallel.
  Sonnet 5 medium unless judgement-heavy.
- Every PR through the `ship` skill; review per PR; Codecov checked (Tier 2+).

## Stage 4 — The next major phase (research starts during Stage 3)

Decision 2026-08-14: research runs as the decoupled second stream while
Stage 3 implementation is the vertical stream, so the direction decision
lands as Stage 3 finishes.

| Step | What | Model / effort | Where | Parallel with |
|------|------|----------------|-------|---------------|
| 4.1 | **Done (2026-08-14, #1384).** One research note per candidate, in `docs/research/`: goals kept small (roadmap Q5), the getting-cold signal / spaced returns, the weekly-lesson loop (#1087), exercises from chord charts (found already shipped in #1110; #1106 closed, #1107 re-scoped), metronome (roadmap Q1). Practice-pedagogy evidence plus Jon's own use. | Fable 5 high, web research on | One session per candidate, or parallel subagents | Stage 3, and each other |
| 4.2 | **Done and decided (2026-08-14, #1385).** [`research/comparison.md`](research/comparison.md): Jon adopted a quick-wins-first order with the weekly-lesson loop as the direction underneath. | Fable 5 high | Lead session | — |
| 4.3 | Work the adopted order in `research/comparison.md`: use the shipped chord-chart flow, the metronome click, tempo capture, then per-piece tracking (#1081, where the Tier-3 spec discipline starts), the Up next card (#1082), the getting-cold signal. **Each slice is shipped and used before the next is specced.** | Fable 5 high (spec + design); implementation models per Stage 3 rules | Spec in lead session; slices as vertical streams | — |
| 4.4 | **Done and decided (2026-09-07).** Stage 4's open question, whether to push the capture line or build the weekly-lesson loop, settled in favour of capture: the loop's tracking half is already shipped, and its entry half is a capture problem. #1080 closes into #1390 (one-pass create), specced in [`specs/one-pass-create.md`](../specs/one-pass-create.md). | Fable 5 high | Lead session | None |

## Exit criteria for the phase

- `docs/audit-2026-08.md` exists and its actionable findings are issues,
  shipped or consciously parked.
- The issue board carries no coach-tainted or stale items.
- A direction is chosen with a Tier-3 spec, and its first slice has shipped.
