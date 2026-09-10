# The coach engine

> **⚠️ Retired 2026-08-13.** The engine specified here was built through Phase
> 2b and removed from the tree; the session-builder product was restored
> (#1344; coach code recoverable from commit 071b85b). Kept as the design
> record. Do not implement from this document.

Technical design spec, Tier 3, 3 August 2026. Resolves
[#1148](https://github.com/jonyardley/intrada/issues/1148) and
[#1147](https://github.com/jonyardley/intrada/issues/1147).

CLAUDE.md's Tier 3 rule has a spec ride with its first implementation PR. This
one shipped alone (#1155), ahead of any Phase 1 code, because it unblocks two
issues Phase 2a waits on and because 400 lines of design argument review better
as a file than as the opening commit of a segmentation PR. A deliberate
exception, recorded rather than inherited.

**Scope:** the seven mechanisms Phase 2a (and, later, the scoring path's
return) cannot be built without — mastery
update, judgement track, session state machine, planner resolution order, FFI
contract, interruption arbitration, gate schema. **Not here:** architecture
([`docs/rebuild-review.md`](../docs/rebuild-review.md)), pedagogy and decisions
1–18 ([the design doc](intrada-practice-coach-design.md), v6), scenarios
([`docs/coach-user-journeys.md`](../docs/coach-user-journeys.md)), UI. §9 lists
what this spec contradicts in those sources — fix them there.

## 1. Boundaries

One quarantined module, `intrada-core/src/engine/`. The gravity risk (review §4)
is held off structurally, not by discipline.

```rust
Model     { …existing…, pub coach: CoachState }
ViewModel { …existing…, pub coach: CoachView }
CoachState { mastery: MasteryStore, judgement: JudgementStore,
             session: EngineSession, ledger: InterruptionLedger, content: ContentIndex }
```

- `engine/` never imports the self-report path (`score: Option<u8>`,
  `ItemPracticeSummary`, `analytics.rs`). One test asserts it; a diff adding one
  is a blocker.
- The single permitted history read is `seed_priors_from_archive()` — one-way,
  once, at migration, never on the live path (review §5's priors note).
- No `local_first` branch in `engine/`: local-first only, dual-mode retired.
- Authored content is `include_str!`-embedded and parsed at startup, so the
  engine does no I/O and the planner stays pure.

## 2. Mastery update (#1148)

Inputs settled by decision 17: **measured attempts only**. Evidence unit is one
**scored attempt**, not one gate — a gate ("3 clean passes at 120") is composed
of attempts, and its pass is a derived event triggering a level-up. State is per
`(node, parameter_level)`; there is no node-level scalar (§9.2).

> **Amended 4 Aug 2026 (decision 18, design doc v6):** with machine listening
> deferred, a scored attempt's verdict is the user's tap against a countable
> criterion. Every evidence record carries a source tag —
> `enum EvidenceSource { TapVerdict, Midi, Audio }` — so machine scoring
> arrives later as a higher-weight evidence class, not a migration. Cold-test
> attempts (first rep of the day on returning material, app-flagged) are the
> highest-information tap-verdicts and carry a `cold: bool` beside the source
> tag — a flag on the attempt, not an `EvidenceSource` variant, since a cold
> MIDI-scored attempt must be expressible later. Nothing else in
> this section changes: the Beta update is source-agnostic.
>
> **Extended 7 Aug 2026 (decision 20, #1244):** a fourth tag,
> `TapVerdictUntimed`, for a tap at l0, where nothing bounds the pass but the
> tap itself (§4). The Beta update is still source-agnostic: l0 is a
> `parameter_level`, so acquisition evidence is held apart by the key it lands
> under rather than by a weight.
>
> **With one door the key does not close.** `level_up` crosses keys by
> construction, and an l0 gate pass seeds the clocked rung above it at the same
> `transfer` a clocked promotion gets. So the separation is complete for
> `record` and incomplete for `level_up`, and the tag is recorded but read by
> nothing. Whether the crossing wants its own constant, and whether
> `EvidenceSource` should carry a weight at all, are calibration questions for
> Phase 0's log: **#1261**.

```rust
struct Mastery { alpha: f32, beta: f32, prior: (f32, f32), last_attempt_at: Timestamp }
```

`alpha`/`beta` are the counts **as of `last_attempt_at`**, never rewritten by the
passage of time. Decay is a read (`decayed_at(now)`), not a stored mutation —
which is what keeps elapsed time out of the spacing calculation twice over
(#1148.2).

**#1148.1 — Beta, confirmed, with three amendments.** Per-attempt pass/fail is
Bernoulli and Beta is its conjugate, so estimate and confidence fall out of one
state with no second mechanism to keep in sync. Rejected: Elo/Glicko (needs an
item-difficulty scale we lack), Bayesian Knowledge Tracing (slip/guess
parameters need population data — decision 4 forbids inventing it), EWMA (no
confidence for free). Amendments: discounted counts (#1148.2); an evidence cap
`alpha + beta <= 40` so a mastered node can still change its mind (velocity,
lever 4, needs that); and three readings defined once, so display, planner and
tests agree:

```
estimate   = alpha / (alpha + beta)
evidence   = (alpha + beta) - (alpha_0 + beta_0)   // attempts beyond the prior
confidence = evidence / (evidence + k)             // k = 8
```

The cap is enforced **on increment, by proportional scale-down** — on reaching
`evidence_max` both counts are scaled to hold `alpha + beta` at the cap, which
preserves `estimate` exactly and discards the oldest evidence implicitly. Two
consequences worth stating rather than discovering: `confidence` therefore
saturates below 1 (at `38/(38+8) ≈ 0.83` with these defaults) and a node is never
certain, which is correct; and a capped node responds to new evidence at a fixed
rate forever, which is what makes three bad sessions visible (lever 4).

Content's `(estimate, band)` seeds become priors: band strength `low 2 /
medium 5 / high 10` pseudo-counts, split by the seeded estimate. User-created
nodes (decision 19, design doc v7) reuse this state unchanged with a `low`-band
prior; their attempts are ordinary tap-verdict evidence, and a confirmed user
drill's attempts feed its host node's mastery at full weight — the
`EvidenceSource` tag is the only distinction recorded.

**#1148.2 — Decay and spacing are one mechanism read twice.** Elapsed time pulls
counts toward the prior, never toward zero:

```
// read-time decay of the stored counts, for display and success prediction
decayed(alpha) = alpha_0 + (alpha - alpha_0) · λ^Δdays        (same for beta)
λ = 0.5 ^ (1 / retention_half_life_days)                     (per node family, authored)

// spacing, computed from the STORED (undecayed) counts
interval_days = base_interval · (1 + estimate) ^ (evidence / e_scale)
overdue       = days_since_last_attempt / interval_days     // due at ≥ 1.0
// base_interval = 2 days, e_scale = 8   (both gates.toml data)
```

What those defaults produce, at four points taken from `content/nodes.md` — the
table is the calibration target, not the formula:

| Node state | estimate | evidence | Comes back every |
|---|---|---|---|
| Brand new, no attempts | seed | 0 | 2 days |
| `rootless-a-b`, current frontier | 0.3 | 8 | ~3 days |
| `shells-ii-v-i`, solid | 0.7 | 16 | ~6 days |
| Fully mastered, at the evidence cap | 0.9 | 38 | ~6 weeks |

Decay shrinks evidence and moves the estimate toward "we don't really know",
never toward failure — journey 7's requirement, and honest: absence of practice
is absence of evidence. **Decay never manufactures failure evidence.**

**The interval is computed from the stored counts, not the decayed ones.** Using
decayed values would put elapsed time on both sides of `overdue` — once
shrinking evidence, which shortens the interval, and again in the numerator — so
a long gap would compound into "wildly overdue" rather than "due". One state,
two readings: the stored counts drive spacing, the decayed read drives display
and the planner's success prediction. `base_interval`, `e_scale` and the
half-lives are `gates.toml` data (lever 2: SM-2 is a heuristic, not gospel), and
the interval form above is the starting shape — expanding in both estimate and
evidence — to be recalibrated against observed decay rather than trusted.

**#1148.3 — Level-ups shift, never reset.** A new parameter level starts from a
discounted inheritance of the level below, `transfer ≈ 0.35`:

```
inherited = min(transfer · evidence_below, inherit_max)     // inherit_max = 6
prior'    = (1 + inherited · estimate_below,
             1 + inherited · (1 - estimate_below))
```

Reset discards real transfer *and* makes every level-up read as a regression —
"I got better and my score dropped" is a trust-ender (UX principle 8). Full
carry-over is equally wrong: a new tempo genuinely is less certain. The level
below is left untouched, so a level-down is a cursor move, not a rewrite.

`inherit_max` matters more than it looks: without it, a capped level below hands
down `0.35 × 38 ≈ 13` pseudo-counts, so the new level needs a dozen contrary
attempts before it will admit the tempo is too fast — an inherited prior that
overrides what the hands are currently saying. Capped at 6, the new level starts
optimistic and is movable within a session.

**#1148.4 — Attempts-to-pass and time-share feed the circling check only.**
Attempts-to-pass *is* the attempt-level Bernoulli sequence seen from the other
end; feeding it in double-counts one piece of evidence. Time-share measures how
the **planner** allocated minutes, and the planner reads mastery — feeding it
back would make mastery partly a record of the app's own choices. Both stay
first-class recorded data (§4), read by the circling check against the user's own
distribution and by gate calibration (challenge 4) as authoring input.

**#1148's fourth listed question** — one mastery estimate or two — was closed by
decision 17 before the issue was read; close it as answered.

## 3. The judgement track

Deliberately smaller: no level, no distribution, no aggregation.

```rust
struct JudgementTarget {
    target: TargetRef,        // Node | PipelineStage | Opaque(String)
    completion: Completion,   // Open | RetiredByYou { at, return_after_days }
    feel: Vec<FeelRating>,    // { at, value: 1..=5, context: BlockId }
}
```

Asymmetric powers (decision 17). **May retire a target** — `RetiredByYou` stops
prescription and schedules a spaced return, which is a prompt, not a gate. **May
never satisfy a prerequisite** — enforced by signature, not convention:
`fn prerequisites_met(node: NodeId, mastery: &MasteryStore) -> bool` cannot see
`JudgementStore`. One test asserts a fully-retired, top-rated target leaves every
downstream node blocked. Opaque targets (decision 13) live here by construction:
no node, so no mastery; a count per normalised string makes the authoring queue
data rather than memory.

**Predict-then-reveal writes to neither track.** A mature-drill attempt carries
`self_predicted: Option<Verdict>` beside its measured verdict; the pair is the
divergence log automated and the evidence base for how much weight the track
eventually earns. It never updates a distribution. *(Deferred with machine
listening, 4 Aug 2026: no reveal exists without a machine verdict. Keep the
field optional and unused until the scoring path returns; do not substitute a
pre-play prediction against a tap-verdict — considered and cut, design doc v6.)*

## 4. The session state machine

> **Scoped 4 Aug 2026 (decision 18):** the machine below is Phase 2a's build
> target and survives the deferral with its transitions intact — what changes
> is what fires them. In v1 the `Listening` → `Verdict` transition is the
> user's tap (there is no "attempt segmented" until the scoring path returns),
> `AttemptSummary` carries no timing facts and an unused `self_predicted`,
> `OffPiste` captures time plus an optional voice note rather than notes
> (journeys doc, decision 16 as scoped), and `WanderRecord.attempts` stays
> empty. "Hands never leave the keys" on the `Verdict` → `CountIn` row reads
> as "one tap, then the count-in" until then.
>
> **Built 4 Aug 2026 (#1176), with two departures from the table below** — both
> forced by there being no machine verdict, both reversed when the scoring path
> returns:
>
> - **`Listening` splits in two.** The one `Listening | attempt segmented |
>   Verdict` row becomes the grid finishing the phrase body
>   (`AwaitingVerdict`), then the user's tap. `AwaitingVerdict` collapses back
>   out once attempts segment themselves.
> - **`Verdict` is the tap, not a state.** With nothing to wait for, a `Verdict`
>   phase could never rest, and a phase no event rests in is a phase the shell
>   cannot render. Its three outgoing rows are three branches of one
>   `resolve_tap` function, and the glance is what `CountIn` draws while the
>   last verdict is still set — which is only until the first count-in click,
>   since that clears it and turns the page back to the during-play facts
>   (T10, #1184). About half a second at 120bpm.
>
> The `Boundary` row is deferred with §7's arbitration: with one seeded block
> there is no interruption to fire and nothing to arbitrate, so a closed block
> goes straight to the next block or `Closing`. `GateOpen`'s **"user continues"**
> exit is deferred too — only auto-advance is built, so `reps_after_gate` is
> recorded on `BlockRecord` and structurally always 0 until there is an
> affordance to continue past an open gate. `circle` and `mode` **are** built
> (#1181): the taxonomy is the fluency frame, defined in `content/README.md`
> "Circle tags" and tagged per node in the content, so nothing had to be
> guessed. They are carried from the parsed node onto the record.
>
> **Persisted 4 Aug 2026 (#1181).** Records leave as they close rather than in
> one batch at session end, so a crash costs at most the block in flight:
> `PersistenceOperation::SaveCoachRecords` appends blocks, wanders and their
> attempts in one transaction with a core-stamped `updated_at`, and
> `AppEffect::SaveCoachSessionInProgress` keeps the in-progress session for
> recovery, rewritten once a rep rather than once a beat.
> `CoachEvent::RecoverSession` re-anchors the clock, so a recovered block keeps
> the minutes already spent against its ceiling and a wander banks none of the
> outage.
>
> **Read back 7 Aug 2026 (#1214).** `PersistenceOperation::LoadCoachRecords`
> returns every closed `BlockRecord`, and a local-first launch replays their
> attempts through the mastery track in timestamp order. The records are the log
> and the mastery store is a projection of them, so the store is never persisted
> itself. Contract: `specs/coach-2a-slice-contract.md` §7.

> **Rebuilt 6 Aug 2026 (#1223), from a fortnight of playing it.** Three
> transitions changed and one state was added; the table below reads through
> this note.
>
> - **`BlockEntry` is where every block starts**, including the first. A silent
>   card carrying the drill title, section, minutes and the planner's why line,
>   with `StartBlock` as its primary action and `SkipBlock` beside it. A phase
>   rather than a `SessionState` variant or a second `CoachView` field:
>   everything the card draws is already `DrillView`, and `Running` keeps
>   meaning what it means, so `spec()`, `mark_cold()` and recovery are
>   untouched. `StartBlock` re-stamps `started_at`, because reading the card is
>   not practice time and the ceiling starts when the hands do; `Tick` will not
>   close a block on its ceiling while the card is up. Recovery does **not**
>   land on a card: a recovered block is mid-flight rather than newly entered,
>   and re-entering it would refund minutes already spent.
> - **The `Verdict` → `CountIn` row is gone.** The click runs unbroken for a
>   whole block, counted in once at block entry, so a tap returns to
>   `Listening` and the glance is ended by the next beat (T10 as amended by
>   T11). `AwaitingVerdict` now *rests* for one phrase cycle rather than until
>   the tap: it opens on the boundary beat, the beats under it are the hands
>   playing the next pass, and the following boundary closes an untapped window
>   with no attempt recorded and opens a fresh one. So a tap still judges
>   exactly one bounded pass and there is never more than one candidate
>   (decision 17), and not tapping costs an unrecorded pass instead of freezing
>   the loop. `CountIn` survives for the two places a pulse legitimately
>   restarts: block entry, and a ladder rung that changed the tempo or the
>   phrase.
> - **`DiscardAttempt` records nothing.** Legal in `Listening` and
>   `AwaitingVerdict`, ignored elsewhere. From an open window it closes the
>   window and lands in `Listening`; from `Listening` it flags the pass in
>   flight so the boundary it reaches opens no window. No `AttemptSummary`, no
>   `ScoredAttempt`, no gate progress, no `consecutive_fails`. A false start
>   must not bias the Beta estimate down.
> - **`ClickInterrupted` parks the block on its card** (#1223 follow-up). The
>   click stopping when the shell did not choose to stop it, an audio
>   interruption, a route change or the app leaving the foreground, is a fact
>   the shell reports and a cost the core decides. It returns the block to
>   `BlockEntry` with `pulse_running` false, keeping attempts, gate progress
>   and mastery: a phone call must not cost banked evidence, which is why
>   `ClickUnavailable` (which ends the session) is too blunt for it. An open
>   verdict window closes with nothing recorded, since the pass was
>   interrupted and a verdict on it would be false evidence. `pulse_seq` does
>   **not** move, because nothing restarts until `StartBlock` does it from the
>   card. A no-op on a card and with no session. From `GateOpen` it closes the
>   block with `Exit::GatePassed` instead: the criterion was met before the
>   interruption, and the card has no way to hold an open gate.
>
>   **Practice already banked survives it.** `BlockState::spent_ms` holds what
>   earlier stretches of the block took, so a block that runs, is interrupted
>   and is resumed is not refunded its minutes: the ceiling still bites and
>   `active_ms` on the record still matches the attempts beside it. A card
>   bills nothing while it is up, whether the block has never started or has
>   been interrupted back to it. Without this, reusing `BlockEntry` for an
>   interruption would silently write `active_ms: 0` on records carrying real
>   evidence.
> - **`SkipBlock` reaches `Exit::Skipped`**, which the machine has carried
>   since 2a with nothing in Swift able to reach it. Legal in any running
>   phase, closes the block and advances to the next card (or `Closing` on the
>   last). A block skipped from its card still writes a `BlockRecord` with no
>   attempts: a skip is a fact worth keeping, not an absence.

> **Clickless from 7 Aug 2026 (#1244), decision 20.** `ClickLevel` gains `l0`
> at the bottom of the ladder, and a block at it has no click, no tempo and no
> count-in. Four rows of the table read differently there, all for the same
> reason: there is no grid.
>
> - **`StartBlock` lands in `Listening`.** There is no count-in to sit through,
>   and one nothing clicks through would never end. `RecoverSession` and an
>   acting escalation rung come back the same way, rather than to `CountIn` or
>   `Escalating`.
> - **The tap bounds the attempt** (Jon's ruling on #1244, 7 Aug 2026). With no
>   phrase boundary to open a verdict window on, `AwaitingVerdict` never opens
>   and the tap is taken from the pass in flight: tap = "that pass is judged".
>   Squared with decision 17 by the evidence class below, since the bound is
>   looser and the record says so. `CountInBeat` and `Beat` are inert.
> - **`DiscardAttempt` has nothing pending to void**, since the tap is the only
>   thing that records, so it clears the glance and writes nothing off. The pass
>   the user goes on to play still counts.
> - **`Tick` ends the tap's glance**, after `escalation.glance_hold_s`. At a
>   clicked level the next beat turns the page (T11); left to a beat at l0 the
>   screen would hold on a phase with nothing to tap, which is the frozen-loop
>   bug one layer up.
>
> Evidence is tagged `EvidenceSource::TapVerdictUntimed`, its own class so
> acquisition evidence never reads as evidence earned against a click, and the
> Beta update stays source-agnostic (§2 as amended, including what `level_up`
> still crosses). `Rung::TempoDown` cannot act at l0, since dropping a tempo
> that does not exist would move the block onto a rung it never practised at,
> so the ladder spends it and moves on to `ShrinkScope`.
>
> **The bridge says so rather than implying it.** `DrillView::tempo_bpm` is
> `Option<u16>`, `None` at l0, and `pulse_running` is false throughout: the
> shell cannot draw a tempo or schedule a click that the rung does not have.
> Adding both variants renumbered their enums, so the crash-recovery blob's key
> went to v3 — a v2 blob still *decodes*, into a clocked block read back as an
> l0 one, which is the #846 class rather than a lost session.
>
> The l0 drill screen itself is unbuilt (#1260) and no content authors an l0
> gate until #1245, so nothing reaches it yet. **#1245 should not land before
> #1260**, or the first authored l0 gate is a screen with nothing to tap.

New machine in `engine/`, beside the legacy `SessionStatus` that Phase 2a
deletes. Off-piste and unmonitored are **peers** of `Running`, not sub-states,
because `Running` implies a plan and gates: `Idle` → `Planned(Plan)` →
`Running { plan, cursor, block }` → `Closing(Summary)`, plus
`OffPiste { started_at }` (no plan, still capturing) and
`Unmonitored { started_at }` (nothing captured, nothing inferred — decision 16).

| From | Event | To | Note |
|---|---|---|---|
| `CountIn` | grid complete | `Listening` | Layer 0: no verdict during play |
| `Listening` | attempt segmented | `Verdict` | one glance, ~1s |
| `Verdict` | fails < trigger, gate unmet | `CountIn` | hands never leave the keys |
| `Verdict` | consecutive fails = trigger | `Escalating { rung }` | acts, doesn't narrate; **no budget spent** (§9.3) |
| `Verdict` | gate satisfied | `GateOpen` | stamps `gate_opened_at_attempt` |
| `GateOpen` | auto-advance / user continues | `Boundary` / `Listening` | continuing is what `reps_after_gate` counts |
| any | ceiling reached | `Boundary` | ceiling shown throughout (decision 15) |
| `Boundary` | arbitration (§7) | next `CountIn` / `Closing` | the only place an interruption may fire |

Entering and leaving the peer states, which the block table doesn't cover:
`Planned`/`Running` → `OffPiste` on one tap, and `Idle`/`Planned` → `Unmonitored`
(never from mid-`Running`: switching to unmonitored part-way through would make
the already-captured half of the session retrospectively unconsented). Both
return to `Closing`, so a wander still banks its time and still closes the
session — abandoning must never be what the app teaches. `OffPiste` → `Closing`
carries the *keep this as a drill?* prompt; `Unmonitored` → `Closing` carries
nothing but a duration.

**Recorded from the first build.** Cheap now, impossible to reconstruct from an
aggregate row later; the circling check, horizons and gate calibration all
depend on them.

```rust
struct BlockRecord {
    id: Ulid, node: NodeId, drill: DrillId, gate: GateId, level: ParameterLevel,
    started_at: Timestamp, ended_at: Timestamp,
    attempts: Vec<AttemptSummary>,     // ordered: verdict, timing facts, self_predicted
    attempts_to_pass: Option<u16>,     // None if never passed
    gate_opened_at_attempt: Option<u16>, reps_after_gate: u16,
    active_ms: u64,                    // time attributed to this node
    escalation_fired: Vec<Rung>,
    exit: Exit,                        // GatePassed | CeilingHit | Skipped | Escalated | SessionEnded
    circle: Circle, mode: Mode,        // the Phase 2 time-by-circle tally, free at write time
}
```

**Off-piste needs its own record, not an optional-everything `BlockRecord`.** A
wander has no node, drill, gate or level, so every id above would have to become
`Option` — which would then let a *planned* block persist with no gate and lose
the type's only real guarantee. Separate type instead:

```rust
struct WanderRecord { id: Ulid, started_at: Timestamp, ended_at: Timestamp,
                      attempts: Vec<AttemptSummary>,   // still captured, still scored
                      keep_as_drill: Option<bool> }    // None = not yet asked
```

`Unmonitored` writes neither — a duration on the session row and nothing else,
which is the whole point of decision 16. Nothing in the engine may infer from it.

Persistence per the invariants: client-minted ulid (3), append-only with
`updated_at` + `deleted_at` (2), `BlockRecord`s in GRDB, the in-progress
`EngineSession` in `crux_kv` for crash recovery (8).

## 5. Planner resolution order

```rust
fn plan(state: &CoachState, ctx: PlanContext) -> Plan
// ctx: available_minutes, now, steer: Option<Steer>, transport: TransportTier, rng_seed
```

Pure: the clock is a parameter, and the only randomness is a seeded dealer for
random-key gates whose seed is stored on the `Plan`, so any session replays in a
test. Five ordered stages, and **each may only remove or reorder candidates,
never add** — that monotonicity is what makes the why generable by construction.

1. **Resolve declared intent.** Goal → campaign target set → today's steer, each
   defaulted so a user who declared nothing still gets a session (decision 9).
   Targets resolve three ways (decision 19, design doc v7): matched targets
   arrive as user drills on their host node, countable-unmatched as user nodes —
   both ordinary candidates from here on — and only the genuinely unmeasurable
   passes through as an opaque target carrying `scored: false`.

   A **built session** (decision 19) short-circuits the stages: `ctx` gains
   `built: Option<Vec<BlockSpec>>`, and when present, stages 1–4 are skipped and
   stage 5 runs advisory-only — the template shape is *reported* as a suggestion
   on the `Plan`, never applied. Blocks keep their gates; evidence lands
   identically to a prescribed session.
2. **Back-chain.** Through graph prerequisites and pipeline stage order to a
   frontier of `(node, level)` candidates. Ambition beyond the hands returns the
   prerequisite plus an honest distance from the user's own trend (decision 10)
   — never obedience, never refusal. The **structural gap read is this stage's
   byproduct**; the statistical read waits for Phase 4 (decision 4).
3. **Block or interleave, by node maturity.** Low `evidence` at the frontier =
   acquisition, so one longer uninterrupted block; matured = shorter interleaved
   passes (lever 1). `overdue >= 1` pulls maintenance ahead of new keys, which is
   how journey 7 falls out rather than being special-cased.
4. **Grind cap.** `grind`-tagged nodes capped by `grind_max_minutes_per_session`
   and `grind_max_blocks`, always parameterised by the in-flight tune, never
   practised in the abstract (principle 4). A grind trade is a logged debt the
   *next* plan reads, not a silent skip.
5. **Template constraints — last, and overriding.** Warm-up on owned material;
   at least one new-or-applied music block; close on music; in-flight caps (one
   phrase, one–two tunes) and time ceilings. **Caps and template outrank declared
   intent**: an over-full campaign is accepted and *sequenced*, and the plan must
   report what it queued. Silent dropping is a defect.

Each `PlannedBlock` carries `why { destination: Option<TargetRef>, node_state,
placed_by: Stage }`, written by the stage that placed it. Test: every block has a
non-empty why citing the destination whenever one is declared (principle 7).

> **Built 4 Aug 2026 (#1180): stages 1, 2, 3 and 5.** `Plan::for_today` reads
> the parsed content: the campaign's targets in declared order (a target may
> name the rung it wants), each preceded by its prerequisites, sized by node
> maturity, then cut to the session length and reordered to close on music.
> What it does not do yet, and why: stage 3 reads the **seeded** estimate, since
> the live mastery store is #1148, and with it waits the `overdue` pull that puts
> maintenance ahead of new keys; stage 4's grind cap has nothing to bite on while
> a node contributes at most one block; and of `why`, only `destination` is
> carried, because `node_state` is a mastery read and `placed_by` has no reader
> until the session-end narrative. A stub target and a rung with no click both
> land in `Plan::deferred` rather than vanishing, and the session length comes
> from `[defaults]` until press-start (#1182) can ask for it.

> **Stage 3 fires for a real user from 7 Aug 2026 (#1214).** The live mastery
> store arrived with #1188, but nothing read the persisted evidence back, so
> `last_attempt_at` existed only for attempts made since launch: the `overdue`
> pull above and the cold test were covered by tests and dead in production. The
> store is now rebuilt at launch by replaying the persisted `BlockRecord`s (§4's
> read-back note).

## 6. The FFI contract

> **Scoped 4 Aug 2026 (decision 18):** the capture types below belong to the
> deferred scoring path — Phase 2a's bridge surface is the tap-verdict event
> and the session/gate state, not `NoteBatch`. Retained as the contract for
> the path's return, carrying the spike's two signature corrections (the
> paragraph after the block) plus one note for typegen: `Range<usize>` does
> not survive facet typegen — anything crossing carries plain start/len
> integers.

Note events cross **in batches, never per-note** (review §3.1): every event
rebuilds the whole `ViewModel`, so per-note crossing is architecture abuse at
playing speed. The entire engine bridge surface, and it does not grow:

```rust
struct NoteEvent { pitch: u8, velocity: u8, on: bool, t_us: i64 }  // signed; from the click anchor
struct NoteBatch { session: Ulid, seq: u32, anchor_us: u64,
                   events: Vec<NoteEvent>, transport: TransportTier }
struct ClickGrid { bpm_milli: u32, beats_per_bar: u8, count_in_beats: u8,
                   click_level: ClickLevel, anchor_us: u64 }
enum  CoachOperation { ScheduleClick(ClickGrid), StopClick, StartCapture, StopCapture }
enum  EngineEvent    { NotesCaptured(NoteBatch), … }   // one ingest event
struct CoachView     { … }                             // one ViewModel field
```

Two of those signatures were corrected by the PR 3 segmentation spike
(`docs/segmentation-findings.md`): `t_us` is **signed**, because two of five
real takes open with a note before the click anchor, and the count-in is
counted in **beats**, which is what the capture harness records.

Rules, from the #846 bincode hazard and review §3.2:

- **No JSON-only serde attributes** on any engine bridge type: no
  `deserialize_with` / `serialize_with`, no `skip_serializing_if`, no
  `Option<Option<T>>`. bincode has no "absent"; a three-state field is an
  explicit enum.
- **Integers where an integer will do** (`bpm_milli`, `t_us`), so timing is exact
  and reproducible rather than rounding-dependent.
- **Bounded batches.** The shell splits at `events.len() <= 512` and delivers per
  beat, per ~250ms, or per attempt window — whichever comes first. An unbounded
  `Vec` on the render path is a latency and allocation hazard.
- **Render coalescing.** `NotesCaptured` returns `Command::done()` unless the
  batch closed an attempt or moved gate progress, so the view rebuild stays as
  low-frequency as the bridge.
- **Round-trip before wiring.** `assert_round_trips` on every bridge type before
  it reaches a screen, plus one `LiveBridge` test pushing a real `NoteBatch`
  through the actual Swift↔Rust wire. A stub bridge cannot catch a wire break.

### The pulse, and how the shell knows what to do with it (#1223, #1224)

The click is the one place the shell owns real machinery, so the contract has
to let it decide **keep clicking** or **restart the click** with no domain
reasoning in it. Four fields on `DrillView` do that:

```rust
pulse_seq: u32,          // restart key; unchanged means leave the click alone
pulse_running: bool,     // false while a block-entry card is up
phrase_beats: u32,       // one pass of the phrase
click_pattern: Vec<bool>,// one cycle of the placement
```

| view says | shell does |
|---|---|
| `pulse_running == false` | stop the click, forget the key |
| `pulse_running`, `(block_index, pulse_seq)` differs from the sounding one | stop, start again with a count-in |
| `pulse_running`, key unchanged | nothing at all |

`pulse_seq` is bumped in exactly three places (a block opening, a `TempoDown`
or `ShrinkScope` rung, and `RecoverSession`) and by nothing else. A tap, a
discard, a beat and a gate opening all leave it. It is block-scoped, hence the
pair.

The pulse is **unbounded in reps**: the shell schedules the count-in and then
body beats forever, topping up a rolling window, and nothing in the view bounds
the schedule. `Beat { beat_index }` climbs monotonically for the whole pulse
rather than restarting each rep, and the core derives the pass
(`beat_index % phrase_beats`) and the bar the musician counts, so nobody reads
bar 41.

**Placement crosses as a mask, not as `ClickLevel`.** Re-exporting the enum
would put a `switch` over domain semantics in the shell, which is what the
dumb-pipe rule exists to prevent. `click_pattern[beat_index % len]` sounds; the
count-in clicks every beat whatever the level. The cycle is a bar or two bars,
never the phrase, because placement is a bar-level fact and a phrase of an odd
number of bars would otherwise flip `EveryOtherBar`'s alternation every pass:

| level | cycle | sounding beats (0-based) |
|---|---|---|
| `EveryBeat` | `beats_per_bar` | all |
| `TwoAndFour` | `beats_per_bar` | 1 and 3, dropped if the bar is shorter |
| `BarDownbeat` | `beats_per_bar` | 0 |
| `EveryOtherBar` | `2 * beats_per_bar` | 0 |

The mask is aligned to `beat_index` 0, which is bar 1 beat 1 of the pulse, so a
`ShrinkScope` rung re-aligns it with the restart and nothing drifts. Accents
stay the shell's business, and an accent on a beat the mask silences is simply
not played.

## 7. Interruption arbitration (#1147)

One budget, one order, one place: five per-feature "once per session" limits are
five interruptions.

```rust
fn arbitrate(candidates: &[Candidate], at: Boundary,
             budget: &mut InterruptionBudget, ledger: &mut InterruptionLedger)
    -> Option<Interruption>
```

- **Budget** 1 per session, 2 when planned minutes ≥ 30. `gates.toml` data.
- **Priority** `StuckWall` > `CirclingCheck` > `GrindTrade` > `CoachVoice` >
  `GapRead` — safety, cost, retention, value, then what can wait (#1147's order,
  adopted).
- **Called from the `Boundary` transition only** (§4), so "never mid-rep" is
  structural rather than a rule each feature has to remember.
- **Losers degrade to the summary** via `Summary.deferred`; nothing fires late.
- **Suppression is persisted**, because the anti-nag rules span sessions:
  `InterruptionLedger` keeps `(kind, subject, last_fired_at, times_fired,
  declined_at)`. Name-the-wall fires once ever per `(node, wall)`; a circling
  notice never repeats for the same node in a later session; a declined offer
  stands without a second ask.
- **Cold start** (journey 1) is one predicate here, not per-feature:
  `baseline_ready(kind)` gates everything needing a personal baseline ("above
  your norm", session horizons, the circling check). Note its input is **not**
  per-node `evidence`: the circling check compares an attempts-to-pass figure
  against the user's own *cross-node* distribution, and horizons need completed
  sessions. So the predicate reads corpus-level counts — gates attempted,
  sessions completed — per `kind`, not the `Mastery` of the node in front of you.
  *Which* mechanism switches on *when* is still open in the journeys doc; this
  predicate is where it gets answered.

The escalation ladder's **action** (tempo down, shrink scope, change mode, swap
drill) spends no budget — the doc's own rule is that it acts rather than
narrates, so it is the plan changing. Only the spoken name-the-wall competes
(§9.3).

## 8. The gate criteria schema

Formalised from `content/gates.toml`, added with the Phase 0 content set
(#1145) and removed with the rest of the coach (#1344): the path no longer
exists, and there is no successor to point at. The gain over its flat bag of
recognised-optional fields: the requirement becomes a closed enum, so an
unrepresentable gate fails to parse instead of silently losing a field.

> **Scoped 4 Aug 2026 (decision 18):** `judge` needs a third value —
> `TapVerdict`, the v1 default: user-judged like `SelfConfirmed` but
> mastery-feeding like `Machine`, which neither existing value can represent
> (`SelfConfirmed` is the decision-3/13 kind that must never unlock). `Clean`
> and `TimingRule` apply only to machine-judged gates; a tap-verdict gate's
> "pass" is the tap, and its `clean` field is `None` by construction. The
> restructure lands with the 2a implementation, as §9.6 already planned.
>
> **Built 4 Aug 2026 (#1176), partially.** `Judge` gained `TapVerdict`;
> `Requirement` carries only `CleanPasses`, because a variant no reader can
> evaluate is a gate that silently never passes. The rest of the struct is
> **not** as written below and lands with the parser (#1180): `tempo_bpm` and
> `click_level` moved to a `ParameterLevel` on the block, since the escalation
> ladder mutates them per block and the gate must not; `time_ceiling_min: u8`
> is `time_ceiling_s: Option<u32>`; and `transport_min`, `self_rating_logged`
> and `clean` are absent, having no reader yet. `Judge` is likewise recorded
> but not consulted — the rule it exists for ("self-confirmation may never
> unlock") bites at the mastery update (#1148), which is where it must be
> enforced rather than merely stated.
>
> **Completed 4 Aug 2026 (#1180).** `Requirement` now carries all four variants,
> each with the evaluation that makes it a gate rather than a label:
> `KeyCoverage` banks a key at a time (which key is in front of you is the
> dealer's business, so it needs no key identity), `Chained` wants the run
> unbroken, and `SelfConfirmed` takes one honest tap. One resolution order turns
> the file's fields into a variant, so a gate matching none of them fails to
> parse, which was the whole gain over a flat bag of optional fields.

```rust
struct GateCriteria {
    id: GateId, node: NodeId, criterion: String,     // prose, display only
    requirement: Requirement,
    tempo_bpm: u16, click_level: ClickLevel,
    judge: Judge,                                    // Machine | SelfConfirmed
    transport_min: TransportTier, time_ceiling_min: u8, self_rating_logged: bool,
    clean: Option<Clean>,                            // None = inherit [defaults]
}
enum Requirement {
    CleanPasses   { count: u8, consecutive: bool },
    KeyCoverage   { keys_required: u8, per_key_passes: u8, first_attempt: bool },
    Chained       { min_keys: u8 },
    SelfConfirmed { max_listens: Option<u8>, first_attempt: bool },
}
struct Clean { max_wrong_notes: u8, timing: TimingRule }
enum TimingRule { Consistent { max_cv: f32, max_drift: f32 } }   // decision 6
```

- **`Clean` is what "a pass" means**, resolved per gate: `clean` overrides,
  otherwise the file's `[defaults]` (`clean_max_wrong_notes`, `clean_timing`)
  apply. Every requirement variant except `SelfConfirmed` is counting *clean
  attempts*, so leaving this implicit would let a gate mean different things in
  two readers.

- **Timing is variance and drift only.** A stable 30ms lay-back passes; mean
  offset is *reported* beside swing ratio and never gated (decisions 6, 8).
  `TimingRule` has one variant on purpose — an absolute-deviation variant would
  be a design change, not a config change.
- **Transport gating is a capability check.** `requirement.capabilities_needed()
  ⊆ transport.capabilities()`, else the verdict is `Ask` — never a pass or a
  fail. Decision 7 and never-bluff, in one function.
- **Validation at load** (`validation.rs` idiom): unknown fields error rather
  than being ignored, `schema_version` must match, every `node`/`gate` reference
  must resolve. A dangling reference is a startup failure, because an unreachable
  gate is otherwise invisible.
- Feedback cadence, escalation ladder, circling thresholds, decay half-lives and
  the interruption budget are all data in the same file. Nothing here hard-codes
  a threshold.

## 9. Divergence from the source docs

### Fixed at the source, in the same commit series

1. **The mastery-function paragraph** (design doc, Technical architecture) now
   points here and says what this spec settled. Its three original claims
   survive; the *how* changed — decay applies to the pseudo-counts toward the
   prior rather than as a separate confidence term, and spacing derives from
   that same state.
2. **Node-level mastery.** "Three mechanisms" read as a node-level `(estimate,
   confidence)`; the mastery-function line said per `(node, parameter level)`.
   Both now state per-level, with any node-wide figure marked display-only.
   `content/README.md`'s day-one checklist says to rate the current rung, since
   the seeds are read as frontier-level priors.
3. **The circling check's free slot is withdrawn.** Layer 2 granted the coaching
   voice one slot "plus whenever the circling check has something to say" — an
   unbudgeted exemption contradicting the journeys doc's "every journey obeys
   the one-interruption budget". It now competes at its own priority (§7). A cap
   with one exception is how five polite features become four interruptions.
4. **The escalation ladder spends no allowance.** The design doc's own rule is
   that it acts rather than narrates, so a silent tempo drop or scope shrink is
   the plan changing, not the app talking. Only the spoken name-the-wall moment
   costs a slot. Stated explicitly in the anti-nag rules; **#1147's list still
   counts the stuck ladder as an interruption and needs the same correction.**

5. **`rootless-traversal` is not a gate**, and no longer sits among them.
   Done with the parser (#1180): it has no pass or fail, so it is
   unrepresentable as a `Requirement`, and it now lives in `[traversal.<node>]`
   as the per-session scheduling quota it always was.
6. **`transport = "paper"` conflated two axes**, and the file now splits them.
   `[defaults]` carries `transport` (`wired | bluetooth | mic | none`) and
   `judge` (`machine | tap-verdict | self-confirmed`) separately, Phase 0 being
   `(none, tap-verdict)` for a counted gate and `(none, self-confirmed)` for the
   micro-transcription rungs. Both restructures waited for the parser rather
   than churning the file the fortnight was practised from.

### Still outstanding

7. **#1148's fourth question is stale** — decision 17 closed it before the issue
   was read. Close as answered rather than answering twice.
8. **The capability check is stated but not enforced.** §8's
   `requirement.capabilities_needed() ⊆ transport.capabilities()`, and its `Ask`
   verdict, have no code: with one transport (`none`) and one judge in play,
   every counted gate is a tap-verdict, so a check that cannot fail is a check
   no test could reach. It lands with the scoring path, alongside the `Clean` /
   `TimingRule` half of the schema.
