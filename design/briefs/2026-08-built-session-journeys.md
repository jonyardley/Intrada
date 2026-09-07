# Design brief — self-directed practice: the built session, play-through, and qualitative capture

*2026-08-07. Informs a live decision: PR #1255 (delete the old session builder,
issue #1190) is parked as draft, CI green, until these journeys are seen and
judged. The question is not whether the old builder's code survives — it is
whether the designed replacement journeys feel right for the two scenarios
below, and what (if anything) must exist before the builder dies.*

## The decision this informs

The old `SessionBuilderScreen` let a user hand-assemble a setlist from library
items (drag, group, per-entry rep targets and durations), then play it with
time tracking and self-rated 1–5 scores. The coach pivot replaces that with
**decision 19's built session**: compose today's blocks from pipelines, nodes
and your own items — each block keeps its gate and its evidence lands in the
mastery model exactly as a prescribed block's does. Strictly richer tracking,
but it does not exist yet (Phase 2b), and its journeys have never been drawn.

Jon's two scenarios to bring to life:

1. **"A few disconnected things."** A lesson hands over a piece and three
   exercises. The user wants to practise exactly those today — but everything
   should still count towards the bigger picture (mastery, ability view,
   future prescriptions).
2. **"Just play through a piece and track that."** No drilling, no gates —
   a run-through, with the session still recorded and informing the model as
   much as the user wants it to.

Plus a cross-cutting layer: **qualitative capture** — these self-directed
sessions are exactly where feel and reflection data adds richness that
tap-verdicts cannot, and it should inform future sessions (indirectly, per
decision 17).

## Spec grounding (specs/intrada-practice-coach-design.md)

- **Decision 11 — never a mode.** The app opens prescribed and never asks.
  Composing is reached for, never chosen from a menu of modes. The built
  session is "the strongest form of today's steer".
- **Decision 19 — three-way target resolution.** Each item the user brings:
  (a) *matches an authored node* → user drill, LLM proposes the match, user
  confirms, evidence feeds that node at full weight; (b) *countable but no
  node* → **user node**: own gate criteria (written at creation, one short
  form or one dictated sentence), own mastery, low-band prior, cold-testable,
  optional *serves* tag (a circle or a named node) for the ability picture;
  (c) *genuinely unmeasurable* → opaque target on the judgement track.
- **Decision 19 — template shape is advice.** Warm-up first, music at the
  ends: offered, declinable. "A shape you can't decline isn't your session."
- **Decision 16 — not everything is data.** Three altitudes below prescribed:
  **built session** (everything gates and counts) → **off-piste** (no plan;
  time logged plus an optional voice note — "found something? say it"; ends
  with "keep this as a drill?") → **unmonitored play** (time logged, nothing
  scored, nothing inferred, no end-of-session prompt).
- **Decision 17 — qualitative data never feeds mastery.** Feel ratings and
  reflections live on the judgement track: they can *retire* a target and
  show trends, never satisfy a prerequisite. They inform future sessions
  indirectly: retirement, keep-as-drill, repeated built-session shapes
  surfacing an undeclared campaign, and (Phase 3) the LLM reading reflections
  to *propose* steers the user confirms.
- **The measurement budget.** One tap per rep; **at most one feel rating per
  block**; reflections always optional; the budget *shrinks* on a bad day.
- **Voice first.** Every text moment has a mic; reflections keep the audio
  and transcribe opportunistically.
- **Tune pipeline.** Pieces are user-added by nature; a play-through is a
  pipeline-stage block with a section-level gate ("bridge, from memory,
  cold") — no note-level target ever.

## What to mock (deliverables)

Use the existing kit (`intrada-design-system.dc.html` — Paper & Score, the
coach primitives: `BlockEntryCard`, `PlanBlockRow`, `TapVerdict`, `GateDots`,
`CoachNote`, `CoachAction`, `PressStartHero`, `ScreenScaffold`). Mock as
`.dc.html` frames saved under `mockups/built-session/`.

1. **Journey A — compose from a lesson.** From the Practice screen (which
   opens prescribed, hero intact): where does "I know what I want to practise
   today" live? Then: adding the piece (→ tune pipeline), adding three
   exercises — one matching an authored node (show the proposed match +
   confirm), one countable-but-unmatched (show user-node creation: the short
   form — criterion, tempo/keys/passes — and the serves tag), one
   unmeasurable (opaque target). Then the composed session view (template
   shape as declinable advice), into the existing drill loop, one block's
   evidence landing.
2. **Journey B — the play-through, three altitudes.** The same piece,
   three ways: as a pipeline block (gated section run-through); as off-piste
   (time + the voice-note moment + "keep as a drill?" exit); as unmonitored
   (entry, the deliberately silent middle, exit). Make the consent
   distinction *visible* — the user should always know which altitude they
   are at and what is being recorded.
3. **Journey C — qualitative capture woven through.** The one-per-block feel
   rating moment; a voice-first reflection at session close (the kept
   improved / still-rough / next-target shape); and one *future-facing*
   frame: how last week's reflections surface when they become tomorrow's
   proposed steer ("you said the bridge rushes — work it today?"), per
   decision 12 (LLM proposes, user confirms, never plans).

## Constraints

- Reuse tokens and primitives; anything new is a signal for `Theme.swift` +
  the design system together. No hand-rolled clones.
- One primary action per screen; content over chrome; progressive disclosure
  (docs/design-principles.md, T1–T12 log).
- Friction is spent deliberately: composition may cost taps; *starting to
  play* may not. Hands stay on the keys.
- British English, musician's words ("crotchet", "bar", "Solid").

## Open questions the mockups should answer

1. Where does composition live so it is reachable-not-modal (decision 11)?
   The old builder hid behind a footer link; the steer surface is 2b's answer
   — what does its strongest form look like *before* the other steer surfaces
   exist?
2. How heavy is first-time item resolution really? The old builder was
   drag-and-go; the new model asks one resolution per new item. Show the
   cheapest honest version — and what repeat use (all items already resolved)
   feels like.
3. Does the play-through scenario need the pipeline at all in v1, or is
   off-piste + a piece tag enough until pipelines are authored?
4. What, concretely, must exist before the old builder can die? (The output
   of this exploration is a keep/kill/sequence recommendation on #1255.)

## Reference

- Old builder frames remain in the design-system screen gallery for
  comparison (they are *retired*, not aspirational — #1253 tracks removing
  them once this is settled).
- The deleted implementation is recoverable from `main` commit `9e92ab2`
  (screens) if any interaction detail needs consulting.
