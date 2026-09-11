# intrada Design Principles

> Living document. Started 2026-05-31. These are **guiding principles**, not
> hard gates — they set direction and frame decisions. When a principle pulls
> against another (or against what the app does today), that's a decision to
> make deliberately, not a rule to mechanically enforce. Document those
> decisions in the **Open tensions & decisions** log at the bottom.
>
> Visual/token detail lives in code (`ios/Intrada/DesignSystem/Theme.swift`)
> and the design rules in `.claude/rules/ios-ui.md`. This doc is the *why* and the
> *interaction* layer those don't cover.
>
> What a screen *says* is decided by [`tone-of-voice.md`](tone-of-voice.md), the
> writing layer of this doc. It inherits these principles; check it before
> writing any user-facing string.
>
> Design is now produced in **Claude Design** — see
> [`design-workflow.md`](design-workflow.md). The native iOS design system lives
> at [`design/intrada-design-system.dc.html`](../design/intrada-design-system.dc.html),
> derived from `ios/Intrada/DesignSystem/Theme.swift`. (Pencil is retired.)

## How to use this doc

- Designing a new surface? Read the interaction principles first, then check
  the open-tensions log for anything relevant.
- Principles conflict? Don't silently pick one. Surface it, decide, and add a
  dated entry to the log so the next person inherits the reasoning, not just
  the outcome.

---

## Visual principles

These are mostly settled and live in code; captured here so the *intent* behind
them isn't lost. (See `.claude/rules/ios-ui.md` for the enforcement
rules and primitive catalogue.)

- **Paper, ink and one marker.** Off-white paper, white cards with a 3pt
  corner and a faint lift, brown ink for text on paper. See T24.
- **Type is colour-coded.** Blue-grey = Piece, sand = Exercise. The
  mapping repeats across card bars and badges; inline dots and checks are ink
  for both kinds. Colour is
  an *accelerator* for recognition, never the only signal (see accessibility
  tension below).
- **One bright colour.** The butter highlighter is the only bright colour:
  primary buttons, the swipe under page titles, the celebration glyph.
  Interactive colour on paper is ink.
- **Warmth bias in semantics.** Danger is a brick red, success an olive green,
  both pulled toward brown ink. The palette leans warm even where convention is
  harsh.
- **Grotesk for words, mono for metadata.** Hanken Grotesk for titles and body;
  DM Mono for the composer, key and tempo line, like a printed programme.
- **Reuse before creating; extend, don't clone.** Hand-rolled markup that
  duplicates a primitive is the top source of visual drift.

---

## Interaction principles

The app's job is to get the user *practising*, not to make them operate
software. Every screen should feel like the shortest honest path to the thing
they came to do — except at the two moments where stopping to think *is* the
thing they came to do.

### A. Spend friction deliberately

- **Friction is a tool, not a defect.** There are two kinds, and they get
  opposite treatment:
  - *Bad friction* — admin, setup, planning, navigation, configuration. Remove
    it ruthlessly. The path to practising should be near-frictionless, intuitive,
    and never overwhelming.
  - *Good friction* — setting an intention just before a practice item, and
    reflecting in the moment right after each item. This is where the product's
    value lives. Preserve it; sometimes deliberately add it.

  The goal is not "fewest steps" everywhere. It's *no wasted steps in the admin,
  and deliberate, well-placed steps where they create meaning.*
- **Keep admin & setup flows short.** Adding a piece, building a routine, saving
  a set, navigating the library — these should feel near-frictionless. If one
  grows steps, treat it as a signal to rethink, not to accept.
- **One primary action per screen.** Each screen has one obvious next step,
  visually dominant (hero CTA / circular button). Secondary actions recede. Two
  actions competing to be "the" action means the screen is ambiguous.
- **Defaults beat configuration.** Every flow should be completable with zero
  setup. Sensible defaults up front; tuning is available but never required to
  proceed.
- **Direct manipulation where the platform allows.** Prefer acting on the thing
  itself (swipe, drag, tap-to-toggle) over opening a form. (Platform caveat in
  tensions log — web needs visible affordances.)

### B. Simplicity — defer complexity, don't remove capability

- **Progressive disclosure.** Show the common path first; advanced options live
  behind a sheet, "More", or Settings. The 80% case shouldn't pay the UI cost of
  the 20% case.
- **Reversible by default; confirm only the irreversible.** Reversible actions
  are instant, optimistic, and undoable (toast). Reserve confirmation dialogs for
  genuinely destructive, non-recoverable actions.
- **The app disappears during practice.** Active practice is the reason the app
  exists. Strip non-essential chrome (focus mode). The user operates the music,
  not the interface.

### C. No clutter — easy to reason about

- **Content over chrome.** Maximise the share of the screen showing the user's
  own data (pieces, sessions, progress) versus navigation and decoration.
- **Glanceable, not just readable.** A screen should be parseable at a glance.
  Lean on the type-colour system and consistent layout so users decode by
  pattern, not by reading every label.
- **Consistency is a simplicity tool.** The same gesture means the same thing
  everywhere; every list→detail behaves the same. Novelty in interaction is a
  cost the user pays, not a feature.
- **One concept per screen.** A screen answers one question or completes one
  task. The urge to add a second unrelated section usually means a second screen
  (or a sheet).

---

## Open tensions & decisions

The principles above pull against each other and against today's app in real
places. Each entry: the conflict, the options, and the decision (or `OPEN`).

### T1 — Where friction belongs: admin vs intention/reflection
**Status:** DECIDED 2026-05-31.
Resolved by the *spend friction deliberately* principle (§A). Setup, planning,
and admin are **bad friction** — make them near-frictionless and unoverwhelming.
But there is **good friction** we deliberately keep: setting an intention just
before each practice item, and reflecting in the moment right after it. A
pre-start review/intention step is therefore not "an extra step to eliminate" —
it's the good kind, *provided* it sits at the intention moment and isn't padded
with admin. Open follow-on: keep the *resume-a-known-routine* path short (don't
force the full builder when the user just wants to continue) — distinct from the
intention beat, which stays. Tracked: jonyardley/intrada#760.

### T2 — Mid-session configurability vs "the app disappears during practice"
**Status:** DECIDED 2026-05-31.
Mid-session editing of duration/reps/focus stays **one layer down** — revealed by
a deliberate gesture (e.g. tap-to-reveal), never persistent chrome. The default
live-session screen stays bare so focus mode holds. Config is reachable, not
resident.

### T3 — Decode-by-colour vs accessibility
**Status:** DECIDED (revisit) 2026-05-31.
**Colour is always an accelerator, never the sole carrier of meaning.** Every
type signal must also carry a shape or text cue (dot, badge text, icon). Today's
`InlineTypeIndicator` (dot + colour) and `TypeBadge` (text) already satisfy this.
Marked for possible revisit, but the rule holds for now.

### T4 — Direct manipulation vs one UI codebase (web + iOS)
**Status:** DECIDED 2026-05-31.
The principle is **"the most direct affordance the platform offers"**, with one
hard floor: **no action may be reachable *only* through a hidden gesture.** iOS
gestures (swipe-to-delete, long-press menu) are accelerators layered on top of a
visible, non-gesture path that exists on every platform (e.g. the action lives in
the detail screen / sheet too). Web users always get a visible affordance.
Follow-on: spot-check that every gesture-only action today also has a non-gesture
path on web (rolls into the T6 audit, jonyardley/intrada#761).

### T5 — Content over chrome vs the 2026 visual identity
**Status:** DECIDED 2026-05-31.
Chrome earns its space on **navigation/structural** surfaces (tab bar, headers,
the brand backdrop). On **content** surfaces, every visual element must serve
recognition, hierarchy, or navigation — not pure ornament. The type gradient
bars stay because they *encode type* (functional, not decorative). Test before
adding a visual flourish to a content screen: *does this help the user decode or
navigate?* If it's ornament only, cut it.

### T6 — Reversible-by-default vs today's confirm sheets
**Status:** DECIDED (principle) + audit pending, 2026-05-31.
Rule adopted: **recoverable actions → optimistic + undo toast; only genuinely
irreversible actions → confirm dialog.** New destructive actions default to the
undo-toast path unless the data loss is unrecoverable. Existing destructive
actions (e.g. item delete's confirm sheet) need a per-action audit to reclassify
— tracked as a follow-on issue.

### T7 — Reflection capture vs "the app disappears during practice"
**Status:** DECIDED 2026-07-14 (vision/journey audit).
Reflection is the good friction T1 protects, but capture must never cost flow.
Rules: **mid-item capture is one tap from the player, saves, and returns
straight to the running timer; it never forces an advance** (the current
hand-off sheet conflates "note" with "next"; that coupling is a bug, not a
design). **End-of-session reflection is structured**: what improved, what's
still broken, what to target next time, shown against the session's stated
intention, skippable, and never a gate on saving. What's captured must feed
forward: the "next target" answer surfaces as the item's suggested aim next
time, and reflections are re-readable (session detail, item history, progress
report). A note the user can never see again is admin, not reflection.

### T8 — Segmented pills are inputs, not a second view of a list
**Status:** DECIDED 2026-07-15 (#1081 B2).
`SegmentedPills` (and pill/tab controls generally) are for genuine **inputs** —
an either/or choice (the Piece/Exercise form toggle, `KindSegment`) or tag
selection. **Do not add a pill row as a filter over content already shown as a
list on the same screen** — that's two controls for one insight and reads as
clutter (violates principle C). B2 originally proposed context filter-pills on
the exercise detail to scope a session history, directly above a "By piece"
rows list that already carried the same per-piece breakdown; the pills were cut
and the rows made to carry it. When a list is on screen, let the rows (with
their own scores/meta, tappable) do the work; reach for pills only for choice
and tags.

### T9 — Session builder: direct manipulation always on, Edit is bulk remove only
**Status:** DECIDED 2026-07-15 (builder UX audit vs `design/Linked Exercises.dc.html`).
The builder's arrange/configure actions must not sit behind a mode switch.
Every line (block header, nested exercise, standalone) is its **own List row**,
so the platform's long-press lift reorders any of them outside Edit (static
grip glyphs advertise it), swipe-to-remove works on every row (mock frame 13),
and tapping a row opens its settings sheet (which carries the visible "Remove
from this session" path — T4's non-gesture floor). Edit/Done shrinks to
**bulk remove** (system minus-circles), per mock frame 14. Invented affordances
that deviate from the mock (chevron tap-steppers, Edit-gated settings glyphs)
were removed. This also **overturns decision 3 of
`specs/related-exercises-redesign.md` (2026-07-01)**: the per-exercise
"include today" toggle returns (off = stays visible but dimmed, excluded from
totals, dropped at session start) — needs a core event, tracked as
jonyardley/intrada#1101. Recorded deviation: the mock draws the block dragging
as one visual unit; here a block moves by its **header row** and the exercises
follow on drop. A custom in-card drag that preserved the unit visual lost a
touch-delivery race against the List's own lift (holding a nested grip lifted
the whole block), so consistency won: the same gesture means the same thing on
every row.

### T10 — The count-in draws on the during-play page, not the verdict glance
**Status:** DECIDED 2026-08-04 (jonyardley/intrada#1184, from playing #1183 at
the piano). RETIRED 2026-08-13. The surface this decided was removed with the
coach (#1344). Kept as log history.
The A3 glance after a tap is deliberate (one fact, nothing to read), but the
count-in is preparation for the *next* rep, so parking it on the page that
judged the previous one read as jarring. Ruling: the glance is the verdict and
gate dots alone, no count-in dots; the first count-in click turns the page to
A2 (tempo, click level, beat position), where the dots draw in place of the
stuck target. The first click is the boundary because it needs no new timer,
and the shortened glance (about half a second at 120bpm) is fine because the
verdict is the user's own tap, an acknowledgement rather than news. Options
considered: turning immediately on the tap lost the glance; keeping A3 for the
whole count-in kept the next rep's facts off screen until the hands were
already moving.

### T11 — The pulse runs for the block, and the beats go either side of it

**Status:** DECIDED 2026-08-06 (jonyardley/intrada#1223, #1224, #1225, from the
Phase 0 fortnight at the piano; design folded into
`design/intrada-design-system.dc.html` in #1232). RETIRED 2026-08-13. The
surface this decided was removed with the coach (#1344). Kept as log history.

**Supersedes the mid-block half of T10.** T10 ruled that the first count-in
click turns the page from the verdict glance back to the during-play facts.
There is no longer a count-in between reps to turn it: the click runs unbroken
for a whole block, counted in once at block entry. So the glance is ended by
the next beat instead, which lands in the same half-second at 120bpm and reads
the same way. Everything else T10 decided stands: the glance is still the
verdict and gate dots alone, and the count-in still draws on the during-play
page, in place of the stuck target, wherever a count-in does happen (block
entry, and after a ladder rung that changed the tempo or the phrase).

Why: the per-rep restart was a cost of deferring machine listening (decision
18), not a design goal. The original loop was continuous (hands never leave
the keys), and stopping the click to ask a question each pass turned a
practice loop into a quiz. The verdict window now opens at each phrase
boundary and rests for one pass while the hands play the next, so the tap is
still a verdict on one bounded attempt (decision 17 is untouched) and missing
one costs a dropped rep rather than a frozen screen.

Three surfaces come with it, all instances of T1: intention friction is worth
keeping, admin friction is not.

- **The block-entry card.** Blocks stop auto-advancing silently. Every block,
  including the first, opens on a silent card carrying four facts and one
  sentence: kind, minutes, drill title with its section, and the plan's own
  why line. Start is the single primary; Skip sits under it with no border or
  fill, because skipping is cheap and the eye should not be drawn to it. This
  is T1's intention beat, and it is where the breath between blocks goes now
  that the loop itself has none. Nothing on the card is configurable (T2) and
  nothing about the block just finished appears on it, so the beat cannot turn
  into a report card. Skip takes no confirm: it is reversible by the planner,
  and a confirm sheet is exactly the stall the card exists to remove (T6).
  Where a boundary CoachNote fires it resolves before the card, never stacked
  with it, so there is at most one thing to read at a boundary. The ceiling
  starts when the hands do, not when the card goes up.
- **Discard.** A false start is not a fail. "Don't count that" records nothing
  at all: no attempt, no evidence, no gate progress, no miss run. Without it
  the continuous pulse makes fumbles expensive, because the loop no longer
  pauses for you to gather yourself. It is a *cheap* action, not a confirmed
  one: reversible-by-default applied to the record rather than to the data.
- **Press start.** The hero shows the shape of the whole session, not just
  block one and a count: the upcoming blocks as read-only rows, and the lines
  the plan could not fit today, worded as the plan wrote them. Deferred lines
  are never dropped, because being told what is not in today is what makes the
  plan trustworthy enough to press start without editing it. The rows carry no
  chevron, no tap target and no reordering, since a per-block decision point
  before playing is a stall, not a choice (research foundation §7). Expanding
  the list shrinks the hero rather than pushing it off screen, so Start stays
  under a thumb at every disclosure state.

Options considered: keeping the per-rep count-in and shortening it (still
breaks the loop, still a quiz); letting the verdict window stay open across
passes until tapped (ambiguous which pass a late tap judged, which is exactly
the attempt bounding decision 17 protects); a confirm on Skip (rejected
above); a tappable block row opening a detail sheet (rejected, it promises a
screen that must not exist); keeping the "N blocks, about M minutes" footnote
alone (rejected, it tells you nothing about what you agreed to).

### T12 — The ramp is a default, not a wall (acquisition before the clock)

**Status:** DECIDED 2026-08-07 (decision 20 in the design doc, from planning
real tune-learning: shells and roots learnt out of tempo in chunks;
engine + planner work tracked in jonyardley/intrada#1244, #1245). RETIRED
2026-08-13. The surface this decided was removed with the coach (#1344). Kept
as log history.

New material opens at the least demanding rung the content authors (l0: no
click, chunked, from memory) and the loop ramps upward: chunks, joins, full
form, then the click below target tempo, then the target. A metronome at first
contact asks for time-keeping from hands still finding the notes; the demand
was arriving a week early.

The guiding-not-prescriptive rules, since familiarity differs per user, per
piece and per session:

- Prescriptions default to the ramp; nothing asks where to start.
- Chunk size is never a parameter: content authors the musical boundaries
  (sections, phrase marks), the block enters at a whole section, a fumble
  splits at the nearest boundary and clean passes merge. Two bars for one
  player's corner, the whole A for another's read-through, from the same
  authored structure.
- Skip on the entry card is the whole "I already know this" interface (T2: no
  mid-session configuration, and no questionnaire before playing).
- Passing a later gate retires the rungs beneath it, so the ramp can never
  hold back what the hands already own.
- Pace is inferred from verdicts alone: clean taps merge chunks and raise
  tempo; struggle falls onto the existing escalation ladder.
- The clock still arrives: an l0 gate that keeps passing gets its clocked
  sibling offered next plan, and the circling check watches acquisition that
  never ends.

Options considered: a "learning mode" toggle (rejected: decision 11, no mode
switches); asking the user to self-rate familiarity at block entry (rejected:
admin friction at the piano, T1, and self-assessed familiarity is exactly what
decision 17 quarantines); keeping acquisition outside the app as unmonitored
prose (rejected: the plan would skip the first week of any new material, and
the evidence from that week would be lost to the mastery track).

### T13 — Voice splits by surface, and the engine never speaks on screen

**Status:** DECIDED 2026-08-07 (graduated from
`design/briefs/2026-08-copy-language.md` v2, decided with Jon while reviewing
the Built Session A/B/C mockups; lands with jonyardley/intrada#1256). RETIRED
2026-08-13. The surface this decided was removed with the coach (#1344). Kept
as log history.

The first copy pass fixed vocabulary but kept the stance: the app narrated its
own data model in nicer words. The fix is not better sentences; it is fewer,
and different rules per surface class.

- **In-session — the silent tool** (drill loop, run-throughs, feel moments,
  off-piste, unmonitored play): prose is budgeted like taps, at most eight
  words beyond labels and buttons. No captions explaining mechanics: what is
  and isn't being recorded is carried by the interface itself (the altitude
  chip; the presence or absence of instrumentation). Buttons and chips are the
  vocabulary: "Held / Broke down", "Fought it / Getting there / It sang".
- **Set-up and composition — the plain peer** (steer sheet, resolution
  questions, composed-session view, altitude choice): one short sentence per
  card, maximum. Explain a thing once, at the decision point, then never
  again; repeat visits get labels only. Questions are fine when they are the
  actual decision.
- **Reflective and narrative — warmth allowed** (session summary, reflection,
  the morning proposal, the weekly thread): the user's own words do the
  emotional work, quoted in serif; the app's words stay brief and concrete
  around them. The only surface class where the app may have a personality.

Universal: engine vocabulary never appears on screen: gate, verdict,
evidence, mastery, prerequisite, node, steer, prescribed, judgement track,
countable, cold test (as a noun). Screen translations: target / the buttons
themselves / history / progress / "you added this" / "today's plan" / "by
ear" / "from cold" (as lived experience). Never explain the data model inline
(if a screen seems to need that paragraph, the design is wrong, not the copy);
no philosophy headlines; buttons name the action, not the mechanism ("Keep it
as a drill", never "write the gate").

The full spec, with worked per-frame examples, is
`design/briefs/2026-08-copy-language.md`; the design system gains a Voice
section beside the tokens so future frames are written against it.

Options considered: one app-wide voice with a softer register (rejected: what
reads warm at session close is chatter mid-drill; the surfaces have opposite
jobs); keeping the consent explanation as on-screen captions (rejected: the
deleted three-bullet consent list on A5 is the type specimen; the interface
carries it, or an ⓘ does); letting spec vocabulary through where it is
"technically accurate" (rejected: core says `variant`, the screen says
**Steps**, and the precedent holds everywhere).

### T14 — The click starts on a tap and only then offers a tempo

**Status:** DECIDED 2026-08-19 (jonyardley/intrada#1398, the metronome click
back in the Focus Player; research note
[`research/metronome.md`](research/metronome.md) §5 slice 1).

**An instance of T2, not an exception to it.** The player's tempo line was a
passive readout of the item's declared target ("Andante · ♩ = 66"). It now
doubles as the click: tapping it sounds a click at that tempo, and only while
it is sounding does the row grow a slower/faster pair either side. At rest the
screen is unchanged, so focus mode holds; the configuration exists one layer
down, revealed by the deliberate gesture of starting.

The tap starts the click rather than revealing a panel to start it from,
because a click at the item's own target is what a musician wants nine times
in ten, and the reveal-then-start version spends a step on the common case to
save one on the rare one. Stopping is the same tap, so nothing here is
irreversible (T6).

Three smaller rulings come with it:

- **The marking belongs to the target, not to the click.** At rest the row
  reads "Andante · ♩ = 66", the composer's mark. Once sounding it reads
  "♩ = 72", because attributing a tempo the musician chose to the marking on
  the page would be the app putting words in the score's mouth. The row keeps
  reading as the click after it stops, too, for as long as the tempo sits off
  the item's own: putting "♩ = 66" back on a row whose next tap sounds 76
  would be a small lie the musician only finds out by ear. Moving to the next
  item reseeds it.
- **A click needs no time signature to be useful.** Every beat sounds the
  same. An accented downbeat would mean asking for a time signature the app
  does not hold and T2 does not want asked mid-session; that, subdivision and
  accent patterns wait for the surface #1366 scopes.
- **The row always exists, even with no declared tempo**, where it reads
  "Click" and starts at a neutral 96. Scales and exercises want a click most
  and declare a target least; hiding the affordance exactly there would be the
  wrong way round. An item carrying a marking but no number ("Andante", no
  figure) counts as no declared tempo here: the marking is not something the
  click can sound, and showing it on a row whose tap plays 96 would be the
  same small lie.

Options considered: a metronome entry in the options menu (rejected: three
gestures deep for the thing you want most while playing, and no place to show
that it is running); a bottom sheet carrying the click (rejected: it covers
the timer, and the running state needs an on-screen home anyway once the sheet
is dismissed); a beat-synchronised pulse animation on the row (rejected: the
player surface sits still while practice runs, per the timer ring, and a
flashing light is a second metronome competing with the first).

### T15 — The Practice hero carries the suggestion, not a play glyph

**Status:** DECIDED 2026-08-27 (Jon; jonyardley/intrada#1082, the Up next card;
mock at
[`specs/up-next-card/design/up-next-card.dc.html`](../specs/up-next-card/design/up-next-card.dc.html)).

The Practice hero was the last thing played, a 96pt play button, and the day.
Where a suggestion exists it becomes the hero instead: the piece, why it is
being suggested, its two or three items with their reasons, and one
`Start · N min`. "Build my own instead" sits under it as the secondary, and
takes the user to exactly the screen that shipped.

**One primary action is the whole of it.** The alternative, and the literal
reading of the issue, was a card *underneath* the existing hero. That puts two
buttons a thumb apart which both begin a session, and asks the user to choose
between them with no basis for choosing. It also repeats itself: the header
subtitle already reads "Last practised Tuesday", and the suggested piece is
usually the last piece played, so the title landed twice on one screen.

Two rulings come with it:

- **Nothing is lost by the hero changing job.** Last practised keeps its line
  in the header subtitle, which is where the tone-of-voice worked example put
  it. The hero stops being an affordance explaining itself and becomes the
  user's own pieces and marks, which is content over chrome (§C).
- **Suggest, never gate.** With no suggestion the hero is exactly what shipped,
  and dismissing gives the same screen. The card cannot become a wall in front
  of the manual builder, and it never blocks a user who wants something else.

Options considered: the card below the hero (rejected above); the card above
the hero (rejected for the same two-buttons reason, and it pushes the week
strip below the fold); a suggestion *line* inside the existing hero with no
item rows (rejected: the reasons are the honest part, and a piece title with
no reasons is the app having an opinion it will not show its working for,
which is the road the coach died on).

### T16 — A tempo is recorded when it was measured, never as a default

**Status:** DECIDED 2026-08-27 (Jon, roadmap open question 3), implemented in
jonyardley/intrada#1420. Supersedes the question that log entry originally
asked.

Tempo capture (**T14**, #1398/#1401) put the stepper on the reflection sheet
for every item and always saved a number, pre-filled from the click. When the
click had never sounded, that pre-fill was whatever `ClickController` had
seeded: the item's own declared target where it has one, and a neutral 96 where
it does not. So a large share of the recorded tempos were a default nobody
looked at, sitting in the same history as real measurements with nothing
telling them apart. **For an item declaring ♩ = 132, that default was 132** —
the app quietly recording the target as achieved, which is a worse falsehood
than a stray 96 and the strongest argument for the ruling.

**A tempo is worth recording when there is evidence behind it, and never
otherwise.** Evidence is either of two things: the user moved the stepper, or
the click was sounding when the item ended, so the pre-filled number measures
what they actually played to. Anything else is a default, and a default is not
data.

This dissolves the original question rather than answering it. Tempo is never
required, and it is not optional-by-item-target either. It is recorded when it
was measured.

Two rulings come with it:

- **The sheet does not change.** The stepper still appears on every item and
  still pre-fills, because a musician reaching for it should find it already
  showing a sensible number. What changed is only whether an untouched number
  is kept, and no banner or hint says so: nothing was asked of the user, so
  there is nothing to report. The one visible consequence is downstream — the
  session summary's meta row reads `Exercise` rather than `Exercise · 96 bpm`
  when there was nothing to measure, which is the row telling the truth.
- **Dialling the click without starting it is not evidence.** The tempo has to
  have been sounding. Changing a number on a silent row is intent, and intent
  is not measurement; the musician never played to it. Deliberate, not an
  oversight.
- **The shell reports, the core rules.** Both facts are shell-observable and
  neither is a judgement, so Swift forwards them untouched and the core decides
  what counts as evidence. Deciding in the shell would be domain logic in the
  dumb pipe, and it would put the rule somewhere no core test could reach it.

Why it matters beyond tidiness: the tempo trend draws this history as a chart,
and a chart looks like measurement. Drawing a line through numbers the user
never considered is the borrowed authority the getting-cold signal (**#1416**)
was careful to avoid, and much harder to spot in a chart than in a sentence.

Options considered: requiring a tempo on every mark (rejected: it taxes every
hand-off for a number most items do not want, and a required field gets
answered carelessly, which is how you manufacture the same noise deliberately);
recording only when the item declares a target (rejected: scales and exercises
declare targets least and want a click most, so it would drop exactly the
measurements worth having); letting the shell send nil (rejected under the
second ruling above).

### T17 — The tempo trend reports what was played, and shows where it did not

**Status:** DECIDED 2026-08-28 (jonyardley/intrada#1420), implemented in
jonyardley/intrada#1425. Follows **T16**, which made the recording honest; this
is how the chart drawing it stays honest.

The chart is a line across the sessions that measured a tempo, on a date axis.
Four rulings, all of them about not claiming more than the data says:

- **A session that measured no tempo breaks the line.** Never a zero, never a
  point interpolated between its neighbours. The line stops and restarts, and
  the session gets a small tick **below the axis, outside the plot**. Inside it,
  a mark on the baseline would read as ♩ = 0, which is precisely the falsehood
  T16 exists to prevent.
- **The count carries the honesty.** `7 of 9 sessions measured`, in one line
  under the plot, is what stops the breaks reading as a fault. It is also the
  one part of the footer that survives at accessibility text sizes; the end
  dates go.
- **Fewer than two measurements is not a trend, and says so.**
  `Measured once, at ♩ = 108 · no trend yet` rather than a one-point chart. That
  ruling is the core's (`TempoTrendView.has_trend`), not Swift's. **Nothing
  measured at all draws no card**, because nothing was asked of the user and so
  there is nothing to report (T16's first ruling, applied downstream). That one is the
  shell's, in `tempoTrendDisplay`, because it is the absence of anything to
  draw rather than a judgement about the data. If a third state ever needs
  distinguishing in copy, it moves to the core.
- **The vertical scale is relative, with a floor.** There are no axis labels:
  the plot shows the shape and the chip carries the numbers. Left unbounded that
  would draw a two-beat drift and a thirty-beat climb identically, so the scale
  never spans less than 8 BPM. Below that the line flattens, which is what
  actually happened.
- **The `♩ = 88 → 116` chip is neutral, never a success colour.** A faster
  tempo is not a better one: deliberately slowing down to fix a passage is
  practice, not a decline. This is where it departs from `RecentSessions`, whose
  mastery chip does go teal on the way up, because a mastery score genuinely has
  a good direction and a tempo does not.

**The item's declared target is not drawn on the plot.** Considered and
rejected: a reference line repeats what is already on screen, and it costs the
trend most of its height (an item at ♩ = 96 working towards 132 loses two thirds
of the plot to empty space above the line). The card is placed **directly under
the Key/Tempo rows** for exactly this reason, on pieces as well as exercises, so
the declared tempo and the measured ones are two lines apart. Mocked as option B
on the [design canvas](https://claude.ai/code/artifact/b0aff8b0-b9e7-45bb-a209-fe8bb866f6fd)
if the call is ever reopened.

**The tempos recorded before T16 stay.** History from #1398 onwards contains
click-prefilled defaults, and the chart will draw them. Accepted deliberately
rather than filtered: nothing distinguishes them from the real measurements a
user made with the click sounding, so any filter would need a cut-off date
invented for the purpose and would delete genuine measurements alongside the
noise. It stops growing at #1422 and ages out as real history accumulates.

### T18 — On a piece, the exercise you write outranks the one the app suggests

**Status:** DECIDED 2026-08-28 (jonyardley/intrada#1431), from Jon's second
round of real use. Spec:
[`specs/piece-related-exercises.md`](../specs/piece-related-exercises.md).
Mocked on the
[design canvas](https://claude.ai/code/artifact/c646b020-6a05-4fe9-9479-73bdbd42528e).

The chord-chart derivation shipped with the loudest affordance on the piece
page: a full-width brand bar reading **See the curriculum**, one tap from five
ready-made exercises. Writing your own sat four taps away inside a picker for
existing ones, and did not even link what it made. The page therefore said the
app's idea of what to practise mattered more than the musician's.

- **The musician's own exercise is the primary action, and it is the card's
  only brand bar.** Choosing an existing exercise drops to plain text beneath
  it. Two brand bars on one screen was the ambiguity that made the page read
  the wrong way round, and removing the chart card's is most of the fix.
- **Creating an exercise on a piece saves it already related to that piece.**
  The primary action is only primary if it completes: a create that leaves you
  to go and tick your own new exercise in a picker has not done the job. This
  is what makes the change a core change rather than a layout one.
- **The derived five are suggestions, offered second, and the word
  *curriculum* goes.** They keep every mechanic they have. What changes is that
  the app now proposes rather than prescribes, which is the difference between
  a suggestion and a syllabus. `Curriculum` becomes `From the chord chart` and
  `Derived in G minor` becomes `Worked out from these changes`.
- **The suggestions live in the Related exercises card**, not on the chart
  card. Everything about exercises for this piece then reads in one place, and
  the idea does not disappear on a piece with no chart, which is most of the
  library. The chart-card placement is mocked as `AltOnChartCard` if it is
  reopened.
- **The suggestions row is drawn as a control, on `surfaceSunken` with the gold
  exercise tint.** Drawn as a plain row carrying only a chevron, Jon read the
  eyebrow above it as the button. A row that creates five library items cannot
  hang its whole affordance on a chevron, and the gold says what will be
  produced before it is tapped.
- **The brand bar belongs to the empty state.** With exercises already in the
  card the primary action recedes to a plain footer action beside "choose one".
  One primary action per screen means one obvious *next step*, and once the
  card is populated, adding another exercise is not it.

**What this does not settle:** whether `Learn the melody` and
`Constrained improv` are exercises at all (#1389), and the chord chart's own
display (#1432). Both were deliberately held out.

### T19 — The click can sound a subset of the bar, and then it must show the bar

**Status:** DECIDED 2026-09-02 (jonyardley/intrada#1364, #1367, #1499; spec
[`specs/practice-instruments.md`](../specs/practice-instruments.md); design
[`focus-player-instruments.dc.html`](../specs/practice-instruments/design/focus-player-instruments.dc.html)).

**Partly reverses T14.** T14 ruled that "a click needs no time signature to be
useful", that an accented downbeat "would mean asking for a time signature the
app does not hold and T2 does not want asked mid-session", and rejected "a
beat-synchronised pulse animation on the row" because the player surface sits
still and a flashing light is a second metronome. Both rulings were correct
**about a flat click** and are wrong once the click sounds a subset of the bar.

The screen budget came first, because with the pass counter on the Focus Player
already ran to the bottom edge. All three instruments are resident, so something
had to give, and what gives is the timer ring:

- **The session timer** sits in the top orientation band, in the slot that was
  28pt of dead space balancing the options menu. Orientation, never feedback: a
  duration cannot praise you. It costs no row, though it does widen both side
  slots, so the position label between them loses horizontal room.
- **The pass counter is always on screen and can be ignored** (Jon,
  2026-09-02, reversing an earlier opt-in-from-the-menu plan). Deciding in the
  builder is the wrong moment, and a menu is a gesture nobody spends
  mid-passage. Untouched it shows no dots, reads `0 of 10`, and **records
  nothing**.
- **The click's pattern is two layers down**, in a sheet. Only the bar line
  stays resident, and only while the click sounds.
- **The ring shrinks from 236pt to about 200pt**, landing with the resident
  counter (#1367) rather than with the timer. A resident counter has to come
  from somewhere, and the ring had the most slack: it is still far and away the
  dominant element. Stated rather than absorbed silently, because it is the
  price of the counter being always there.

This is a real departure from T2's "the default live-session screen stays bare",
and it is deliberate: counting passes is not configuration, it is the practising.
Configuration (the metre, the pattern, the target) all stays one or two layers
down, which is the part of T2 that still binds.

Six rulings come with it.

- **A pattern never divides the tempo.** The pulse grid keeps its rate and the
  pattern gates which beats sound. This is the whole point: "practise at 120
  with the click on beat 4" used to require setting 30, and the app wrote 30
  down. `achieved_tempo` therefore keeps meaning what T16 says it means.
- **The row must never imply every beat when it is not.** The pattern dots are
  the honesty mechanism, and they are the same argument T14 made about putting a
  marking back on a row whose next tap would sound something else. Filled and
  hollow, never colour alone (T3).
- **The bar gets its own line, under the tempo.** T14 made tapping the readout
  the start/stop toggle, so the readout cannot also open the pattern sheet: the
  two gestures would collide on one target. Line one stays exactly T14's row;
  line two carries the metre and the dots, appears only while sounding, and owns
  the sheet. It also gives the travelling indicator room to be legible from a
  music stand.
- **The metre is offered with an answer already in it, never asked for.** This
  is what dissolves T14's objection rather than overruling it: the app now holds
  a metre (from the piece, and the chart derives from it), so nothing is
  demanded mid-session. Three presets cover nine cases in ten; "Other" opens
  beats-in-the-bar, the beat value and the grouping, so 5/8, 7/8 and 9/4 are the
  same mechanism as 4/4 rather than a special case.
- **The grouping is the accent pattern.** In 7/8 the useful fact is 3+2+2, not
  seven equal beats, so the bar carries its grouping and "sounds on group
  starts" becomes one tap in any metre. It also fixes the layout: above six
  beats the grid takes one row per group, which reads as the shape of the bar
  and keeps every cell a real tap target. Seven identical squares would make the
  user toggle each one to get a click any Balkan player calls standard.
- **A travelling indicator, not a flash.** Two reasons it is a small ring on the
  pattern dots rather than a pulsing panel. It must say *which* beat, because a
  click on beat 4 at 120 sounds exactly like a flat click at 30 and the ear
  cannot separate them either. And at the top of the tempo range (208bpm, 3.5Hz)
  a large high-contrast flash crosses WCAG's general flash threshold, while
  ceasing to be legible anyway. The dots therefore show whenever the click
  sounds, not only when the pattern is a subset, so the indicator always has a
  home.

**The indicator reads the audio's clock, not its own.** `ClickEngine` schedules
beats on a host-time grid precisely because a timer-driven click drifts, and the
existing poll runs at 100ms, which is 20% of a beat at 120bpm. A view animating
off its own timer drifts *against* the click, and a light visibly separating
from the sound is worse than no light. The pure `schedule(beats:pulse:)` is the
shared source of truth.

**A displayed target is not a recorded one.** Because the counter is always
drawn, the target it draws against must be a view concern; `rep_count` and
`rep_history` stay unset until the first tap. Otherwise every entry banks a
zero nobody earned and the summaries fill with defaults, which is T16's exact
failure mode a third time.

**Reaching the pass target is not congratulated.** The dots fill, `Got it` greys
out, and the count drops its "to go" clause. Tone V1: the app has no microphone
and does not know how it went, so a banner at ten would be the notebook claiming
to have listened.

**`Passes`, `Got it`, `Not quite`.** `Passes` replaces `Repetitions`. Both
buttons change, because `Clean` and `Missed` were mismatched in kind: one
described the pass, the other the player, and you miss a note rather than a
pass. `Got it` is already the core's own word for this (`SessionEvent::RepGotIt`),
British, and warm without boasting. `Not quite` narrows nothing, covering
slipped notes, rushing and stiffness alike, and reads `Not quite right` at
accessibility sizes where the pair stacks. The two halves are deliberately equal
in length and register: a pair weighted toward the gentle option biases the tap
and skews the count low, which is the same concern behind the coach-era ruling
that a miss must be equally hittable. Rejected: `Fluffed` (jokey at twenty taps
a session, and it blames the fingers), `Nailed it` (a US idiom where British is
mandated, and it overclaims a routine `+1`), `Clean / Not clean` (symmetrical
but dead), `Solid / Scrappy`, `Clean / Rough`.

Options considered: a metre picker on the resident row (rejected, it is the
resident chrome T2 forbids and it would push the transport off screen); a
scrolling row of metre pills out to 12/8 (rejected, still a finite list and 11/8
is undiscoverable); typing the signature (rejected, `TempoStepper` exists to
keep a keyboard out of a mid-session sheet); a tick travelling the timer ring's
rim (rejected, the ring is the per-item timer and overloading it muddies both);
a background flash (rejected on the flash threshold above); flat beats with a
cell-by-cell grid for irregular metres (rejected, it makes 7/8 fiddly every
single time for the sake of one less field); the pattern inline on the tempo row
(rejected, it collides with T14's toggle and leaves the dots too small to read
at arm's length); the counter behind the options menu (rejected by Jon above).

**What this does not settle:** an accent timbre on the downbeat, subdivisions,
whether a dotted crotchet can be named as the felt beat in 6/8, and what unit
the tempo trend labels its axis with. All held out in the spec's open questions.

### T20 — The starred route is a text action under the hero, never a second button

**Status:** DECIDED 2026-09-05 (jonyardley/intrada#981, the screens half; the
core half in #1540 and #1544).

**Reads T15 forward rather than reversing it.** T15 ruled that a card under the
Practice hero puts two buttons a thumb apart which both begin a session, and
asks the user to choose between them with no basis for choosing. "Practise your
priorities" is a third way in, so drawn as a filled CTA it lands in exactly that
trap. The issue's own wording (an entry point on "the Priorities section header
in the Library, and/or the Practice tab") predates both the star filter that
replaced that section and the Up next card that took the hero.

So the route is one line: a star glyph and three words, in secondary ink, under
whichever hero is showing. One primary action per screen survives, and the
starred set reads as an alternative rather than a rival.

Three rulings come with it:

- **It shows only from Idle.** The core refuses the event outside Idle with "A
  practice is already in progress", so a button surviving into building, playing
  or the summary would raise an error the user never caused. The shell gate is
  `PracticeScreen.showsPriorities`, and deleting any clause of it fails a test.
- **Nothing starred, nothing offered.** The flag is derived before the library
  filter (#1544), so filtering to exercises cannot make the route flicker out
  from under a musician who just starred a piece.
- **Two secondaries under one primary is fine; two primaries is not.** With a
  suggestion on screen, "Build my own instead" and "Practise your priorities"
  both sit under one Start. Both are text, neither competes with it, and that is
  the layout a snapshot now pins, because it is the one that can drift.

Options considered: a filled button under the hero (rejected, T15's exact case);
making the starred set the hero when anything is starred (rejected, the
suggestion already owns that slot, and a star is a standing preference rather
than a statement about today); putting it on the Library star filter instead
(not rejected, deliberately held: it is a different question about where a
musician goes looking, tracked as #1538).

### T21: Adding a piece captures what it can carry, in one pass

**Status:** DECIDED 2026-09-07 (jonyardley/intrada#1390; spec
[`../specs/one-pass-create.md`](../specs/one-pass-create.md)). The layout is
settled at the Claude Design pass before the screens PR; what is decided here
is the shape that pass works inside.

Adding a piece is admin, so its friction is the bad kind (§A). Today the chart
and the exercises are two further trips through the piece's detail screen, and
nothing on the create form says either is possible, so both depend on having
found them once before.

Four rulings.

- **The minimal form stays minimal.** The chart and the exercises are two
  collapsed rows below the fields, not two more always-open sections. The
  common case, a piece with neither, pays nothing for the case that has both
  (principle B).
- **Nothing is written until Add.** The staged chart and exercises are shell
  state, and the core validates everything before it mutates anything, so a
  parse error in bar 24 leaves no half-made piece behind.
- **What the form captures is the musician's own material, never the app's
  suggestions.** T18 put the chart-derived five in the Related exercises card
  on the piece, offered after it exists. Generating them at create time would
  have the app write five library items before the musician has seen the piece
  save once, which is prescription wearing capture's clothes.
- **The chart sheet is extended, not cloned.** On the create path there is no
  piece id to send `SetChordChart` to, the same shape phase B hit when
  `ReadPhoto` ended up taking only a `photo_id`.

**What this does not settle:** whether the edit path grows the same sections
(held: create is where the material is fresh), the per-bar parse feedback the
text format still wants (#1387 part 1), and the words on the two rows, which
are matched to the detail card at the design pass rather than invented here.

### T22: "Build my own instead" opens the builder, and dismissal is never a one-way door

**Status:** DECIDED 2026-09-10 (jonyardley/intrada#1617, #1618). Amends T15's
"takes the user to exactly the screen that shipped": revealing the plain hero
and asking for a second tap turned out to be one tap too many for a decision
the musician had already made.

Two rulings, read together:

- **The tap does the thing it names.** "Build my own instead" is a decision,
  not a dismissal, so it drives straight into the empty builder in the same
  tap that hides the suggestion. Nothing else about T15 moves: the suggestion
  is still the hero, still suggests rather than gates, and the manual builder
  is still exactly the screen that shipped once you are in it.
- **A curious or accidental tap is not a one-way door.** Once dismissed, the
  plain hero carries a text route back to the suggestion ("Show suggestion"),
  on the same footing as T20's starred route: both are secondary text actions
  under one primary, and both can show together, so the busiest case stacks
  two secondaries rather than one. `suggestionDismissed` stays shell-local
  `@State`; nothing about which sessions the core offers to suggest changes.

Options considered: leaving "Build my own instead" as dismissal-only and
adding a separate always-visible "Build session" entry point elsewhere
(rejected: reads as a second primary action next to Start, the exact trap T15
and T20 both ruled out); bringing the suggestion back automatically after a
cool-down rather than on a tap (rejected: a timer is a rule about the user's
attention the app has no basis for, and re-litigates T15's "never a gate" in
the other direction).

### T23: A weak photo read dims the glyph, never the label

**Status:** DECIDED 2026-09-11 (jonyardley/intrada#1458). #1436 settled that a
weak read wears the same "From the photo" mark, dimmed, with the difference
also spoken to VoiceOver. The dim chosen was `inkFaint` on the whole mark, but
`inkFaint` is documented as failing WCAG AA on text (2.9:1) and the mark is
10pt body text, not an eyebrow.

The label ("From the photo") stays at `inkSecondary` in both states: it is
text, so the 4.5:1 AA floor applies and there is almost no headroom above it
to dim into. Only the leading glyph dims, to a new `inkFaintIcon` token
(3.29:1 on `cardFill`), which clears the 3:1 floor WCAG sets for a non-text
graphical object. The visual difference is now the glyph alone; VoiceOver
still speaks the weak state explicitly, so contrast is not the only channel.

### T24: One marker on paper replaces indigo and serif

**Status:** DECIDED 2026-09-11 (jonyardley/intrada#1676). The Claude Design
visual direction exploration settled on "8f": paper #F7F4EF, white cards, brown
ink #3B2A1E, 3pt corners, a faint lift, and a butter highlighter #FFE9A3 as the
only bright colour. It retires two earlier principles: indigo as the
interactive colour, and serif page titles.

Interactive colour on paper is ink, not the marker: butter text on paper is
about 1.1:1 and cannot carry a link or an outline. The marker is a fill, with ink
on it (11.3:1), on primary buttons, the hero's start button and the swipe
under page titles. The Practice hero and the celebration toast become dark ink
surfaces with butter as their one accent, so no second hue enters.

Type colours are duller pastels than the marker, so a piece badge never reads
as a button. A check or outline stays ink for both kinds, because a pastel
border on white misses the 3:1 WCAG sets for a control. The practice player
stays light for now, its ink buttons included; a dark focus screen is #1679, and choosing your own marker
is #1677.

### T25: The Practice greeting leads the subtitle

**Status:** DECIDED 2026-09-11 (jonyardley/intrada#1690). The Practice screen
greets the musician by name at the start of the subtitle under its title, and
the last-practised fact stays after it: "Morning, Jon · Last practised
Tuesday". That keeps T15's ruling that last practised holds its line in the
header, since the Up next card shows no date. Morning is 04:00 to 11:59,
afternoon 12:00 to 17:59, evening 18:00 to 03:59; the core owns the rule and
the string. With no name set, the subtitle stays as it was ("No sessions yet"
or "Last practised Tuesday"). The wording is tone-of-voice V6.

The rejected alternative put the greeting in the title and left "Practice" to
the tab bar. It is warmer, but every other tab titles itself, and a title that
changes through the day is harder to find by eye.

The way into the profile is the musician's own instrument icon on their
highlighter, top right of Practice: 36pt in the same 44pt target as the
Library's add button, a new marker-filled trailing style rather than the ink
one, read as "Profile" by VoiceOver. With no profile yet it shows the plain
note on butter. It is the only way in. The mocks are
`design/Profile and Greeting.dc.html`.
