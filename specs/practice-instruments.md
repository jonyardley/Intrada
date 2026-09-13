# Practice instruments: the session timer, the pass counter, and an honest click

> **Tier 3.** Crosses the FFI bridge, changes the on-device schema and moves a
> field between domain types, so the domain-sensitivity override applies
> regardless of size. This spec rides with the first implementation PR.
>
> Covers [#1364](https://github.com/jonyardley/intrada/issues/1364) (an overall
> session timer), [#1367](https://github.com/jonyardley/intrada/issues/1367)
> (the pass counter), [#1499](https://github.com/jonyardley/intrada/issues/1499)
> (which beats the click sounds, and the time signature that makes that mean
> something), with [#1402](https://github.com/jonyardley/intrada/issues/1402)
> folded in. One round by Jon's decision of 2026-09-02, because all three
> compete for the same strip of the Focus Player.
>
> Design: [`practice-instruments/design/focus-player-instruments.dc.html`](practice-instruments/design/focus-player-instruments.dc.html).
> Rulings: design-principles **T19**.

## The problem

Three separate gaps in the live view, which turn out to share one screen and one
schema change.

1. **No overall session timer.** The Focus Player's ring times the *current
   item*. Nothing says how long you have been practising.
2. **The pass counter is unreachable in practice.** It is fully built (see
   "What already exists"), but it only renders when a target was set in the
   builder, before you have played a note, and the increments are not
   timestamped.
3. **The click lies about the tempo.** `ClickEngine.start(bpm:)` sounds every
   beat identically. To practise with the click on beat 4 of a bar at 120 you
   set it to 30, and the app writes 30 down. `TempoObservation.click_sounding`
   is what makes a tempo *evidenced* (T16), and that ruling is only sound while
   the click's rate equals the music's tempo.

## What already exists (and changes the shape of this work)

**The pass counter is shipped, not shell-dead.** `SetRepTarget`, `RepGotIt`,
`RepMissed` and `InitRepCounter` were in the core with handlers, `freeze_rep_state`
and auto-init on `StartSession` (the last two are gone since PR 3); `MIN_REP_TARGET`/`MAX_REP_TARGET` are 3 and 10;
`ActiveSessionView` projects all four fields; GRDB and the API both persist the
history; `RepCounter.swift` renders in the Focus Player and has a snapshot test.
Full audit on [#1367](https://github.com/jonyardley/intrada/issues/1367#issuecomment-5516548349).

So #1367 is a wiring job plus one schema delta, and **#1499 is the only
untouched surface in the round**. The session timer needs no core change at all:
`ActiveSessionView.started_at` already carries the session anchor and no screen
reads it.

## The three questions #1499 said must settle before code

### 1. Where the time signature lives

`ChordChart.metre: u8` is a bare beats-per-bar with no denominator. It **cannot
represent 7/8 at all**, so it is not a candidate for the authoritative field
once irregular metres are in scope (Jon, 2026-09-02).

**Decision: the metre moves up to the item, and the chart reads it.** One field,
so a second source of truth cannot exist.

```rust
/// A time signature, plus how the bar is counted. `groups` is what makes
/// "sounds on group starts" mean something in 7/8; `None` = undifferentiated.
pub struct Metre {
    pub beats: u8,          // numerator: 2 to 12
    pub unit: u8,           // denominator: 2, 4 or 8
    pub groups: Option<Vec<u8>>,  // sums to `beats`; enforced in validation.rs
}
```

- `Item.metre: Option<Metre>`. `None` means the piece does not declare one.
- **`ChordChart.metre` is removed.** `assign_beats` takes the metre as an
  argument, supplied by the item at parse time.
- Migration: for every item with a chart, `metre = Metre { beats: <old u8>,
  unit: 4, groups: None }`; the chart's column is dropped by copy-table, or
  left in place and ignored if that is cheaper on device (append-only rule:
  prefer ignoring to dropping).
- The live sheet's metre is a **session-local override** that never writes back
  to the item. Changing it mid-session is a click setting, not a library edit.

Rejected: keeping `ChordChart.metre` authoritative with an `Item` fallback. Two
fields that can contradict, and the chart's is the wrong shape anyway.

### 2. Whether `achieved_tempo` still means one thing

**Yes, and it takes two mechanisms to keep it that way.**

- **A pattern never divides the bpm.** The pulse grid stays the same rate;
  the pattern gates which beats *sound*. So a click on beat 4 at 120 is still
  120, and `TempoObservation::is_evidenced` is unchanged. A sparse click is
  arguably stronger evidence, not weaker.
- **A denominator other than 4 changes the unit, so the core normalises.** In
  7/8 the pulse is a quaver and the row reads `♪ = 168`. Stored raw that is
  double the truth, and it would land in the tempo trend (T17) beside crotchet
  values. `achieved_tempo` keeps its existing meaning of **crotchet BPM**, and
  the core converts: `crotchet_bpm = round(displayed * 4 / unit)`, rounding half
  away from zero, i.e. `(displayed * 4 + unit / 2) / unit` in integer
  arithmetic.

  **The rounding rule is stated here on purpose.** For `unit: 8` the multiplier
  is one half, so every odd displayed value has a half-BPM to lose: `♪ = 169`
  must become 85, not 84. Left unstated, the table test would be written against
  whatever the code happened to do, which is the failure CLAUDE.md's
  parser-and-validator rule exists to prevent. `unit: 2` and `unit: 4` are exact.

The shell reports what it displayed plus the click's state; the core rules and
normalises, per the dumb-pipe rule and #1420's contract.

```rust
/// What the click was set to when the item ended. Facts only, like
/// `TempoObservation`: the core decides what they mean.
pub struct ClickState {
    pub metre: Metre,
    /// Bitmask over `metre.beats`, LSB = beat 1. Fixed width and cheap to mask;
    /// a `Vec<bool>` would serialise fine but costs a length prefix per entry.
    pub sounding: u16,
}

UpdateEntryTempo {
    entry_id: String,
    tempo: Option<u16>,        // as displayed, in `metre.unit` beats per minute
    observed: TempoObservation,
    click: Option<ClickState>, // None when the click was never configured
}
```

### 3. Whether the click pattern is recorded alongside the tempo

**Yes.** "120 with the click on 2 and 4" is a different achievement from "120
straight", and without the pattern the trend draws them as the same point, which
is the borrowed-authority failure T17 was careful to avoid.

`SetlistEntry.click_pattern: Option<ClickState>`, written by the same handler
that writes `achieved_tempo`, and only when the click was sounding: a number
the user typed against a silent click evidences the tempo, not a pattern. No
new network or storage op: it rides the existing session row.

## The pass counter is resident, and an untouched one records nothing

**Decision (Jon, 2026-09-02): the counter is always on screen, and can be
ignored.** Not opt-in from the options menu, which was the earlier plan:
deciding in the builder is the wrong moment, and a menu is a gesture nobody
spends mid-passage.

That makes an old trap live again. If every entry gets a target so the counter
can render, then `StartSession`'s current behaviour gives every entry
`rep_count: Some(0)` and an empty history whether or not the musician ever
looked at it, and `ItemPracticeSummary` fills with zeroes nobody earned. This is
exactly T16's failure mode, a third time.

**The rule: a target is written when the counter is first used, never at session
start.**

- **All four rep fields stay `None` on an untouched entry.** Such an entry is
  indistinguishable from today's entries with no target, and contributes nothing
  to `ItemPracticeSummary`.
- **The first tap writes all four**, target included, and records itself. This is
  what `InitRepCounter` did, so it became the first step of `RepGotIt` /
  `RepMissed` (`record_rep`) and the event itself was deleted: no Swift caller
  ever sent it. Both handlers used to guard on `(Some(target), Some(count))` and
  would otherwise have no-oped forever on a `None` entry.
- **`StartSession` stops pre-initialising.** Its `rep_target.is_some()` branch
  (`session.rs:1186-1189`) goes: with the counter resident, that branch would
  bank a zero and an empty history on every entry in the setlist.
- **The 10 the counter draws against before the first tap is a view concern**,
  projected for the counter to render, and distinct from the `DEFAULT_REP_TARGET`
  the first tap writes. Naming them separately is deliberate: the drawn number
  must not imply a recorded one.

`DEFAULT_REP_TARGET` rises from 5 to 10, which makes it equal to
`MAX_REP_TARGET`. That is intended, not an oversight: the `3...10` stepper
exists to let a musician ask for *fewer* passes than the default ten, never
more. Two shell constants have to move with it, or the builder and the player
disagree: `EntrySettingsSheet.swift:26,34` hardcodes the `3...10` range and an
`?? 5` fallback that mirrors the Rust constant by hand.

## The pass counter's one schema delta

`rep_history: Option<Vec<RepAction>>` records the sequence but not the time. The
issue's stated reason for the history is trajectory, and sequence alone cannot
tell a steady ten from a hard-won one.

```rust
pub struct RepEvent {
    pub action: RepAction,     // Missed | Success, unchanged
    pub at: DateTime<Utc>,
}
```

`rep_history: Option<Vec<RepEvent>>`. The core cannot read the clock, so
`RepGotIt` and `RepMissed` gain a `now: DateTime<Utc>` the way `SkipItem` already
does.

**Default target rises from 5 to 10**; the `3...10` stepper stays (Jon,
2026-09-02). `MAX_REP_HISTORY` stays 500.

## The UserDefaults key bump, paid once

`RepEvent` and `click_pattern` both land inside `SetlistEntry`, which sits in
`ActiveSession`, the positional-bincode crash-recovery blob written by one
build and read by the next. `#[serde(default)]` does nothing on a
non-self-describing wire, so an old blob would decode into a valid-looking wrong
session (CLAUDE.md gotchas, #1345).

**One key bump covers both changes**, so the round pays this cost once rather
than twice. In-progress sessions do not survive the upgrade; that is the
accepted price, and it is the reason these two ship in the same round rather
than separately.

## The click's two lines

**The tempo row and the bar are separate lines** (Jon, 2026-09-02). This is not
only tidiness: it fixes a collision. T14 made tapping the readout the start/stop
toggle, so the readout cannot also open the pattern sheet.

- **Line one is exactly T14's row**, unchanged: the metre steppers either side of
  a readout whose tap starts and stops. The resting screen keeps one line.
- **Line two appears only while sounding** and carries the metre and the beat
  dots. It is the sheet's tap target, so the two gestures never compete.

It also buys the travelling indicator room to be legible from a music stand,
which a readout-inline row could not.

## The click engine

`ClickEngine.schedule(beats:pulse:)` is already pure and beat-indexed, which is
the seam. Two changes:

- **Gate by beat index.** `schedule` keeps laying out every pulse on the
  host-time grid; the caller skips `scheduleBuffer` for a beat the pattern
  silences. The grid never changes rate, which is what keeps the tempo honest.
- **A display-linked beat indicator, not a flash.** The travelling dot must
  derive the current beat from the same `pulse.scheduledStart + index ×
  secondsPerBeat` the audio uses. A view driven by its own timer drifts against
  the click, and the existing 100ms poll is 20% of a beat at 120bpm. Reasoning
  and the accessibility constraint: T19.

## PR order, smallest first

Each is independently shippable. The two core-plus-shell pairs follow the
core-first rule, with the core PR carrying the minimal plumbing its signature
change breaks.

1. **#1364, the session timer.** Shell only. The orientation band grows a left
   slot; VoiceOver distinguishes it from the ring; one snapshot.
2. **#1402, tempo constants.** Shell only. A `TempoScale` enum in `Core/` owns
   `range`, `step`, `clamp`, `stepped` and the default (`Tempo` is taken by the
   generated `SharedTypes.Tempo`); `TempoStepper`, `ClickController` and
   `ReflectionSheet` read it.
3. **#1367 core.** `RepEvent`, `now` on the rep events, the displayed-target
   projection, `StartSession` no longer pre-initialising, the key bump, GRDB and
   API codec updates, round-trip and upgrade-path tests, plus the plumbing the
   event signatures break.
4. **#1367 shell.** The resident counter and its quiet untouched state,
   "Passes" copy, the at-target state, the reclaimed vertical space, snapshots.
5. **#1499 core.** `Metre` on `Item`, written by `ItemEvent::SetMetre` (kept out
   of `Update` for the same reason as `SetPhoto`), `ChordChart.metre` removed
   and the chart's beats derived again when the metre changes, the migration
   (v17 backfills a charted piece's metre from the chart's old field, left in
   place and ignored) and its upgrade-path test, `ClickState`, the extended
   `UpdateEntryTempo`, crotchet normalisation, `click_pattern` recorded only
   when the click was sounding.
6. **#1499 shell.** Beat-index gating in `ClickEngine`, the display-linked
   indicator, the click sheet with the metre picker and group editor, snapshots.

## Tests that are preconditions, not follow-ups

- `assert_round_trips` on `Event::Session(UpdateEntryTempo { .. })` and the rep
  events with their new payloads, over the **real** bridge (`LiveBridge`), before
  either is wired to a screen. A stub-bridge test cannot catch a wire break (#846).
- A wire-pin test on the bumped `ActiveSession` blob, so the next field addition
  fails loudly instead of decoding wrong. This is the technique #1223/#1244/#1256
  arrived at, and porting it to this blob is a tracked follow-up of #1344; this
  round is the right place for it.
- The migration test runs from a DB **populated at the previous version** and
  asserts charted pieces keep their metre.
- Normalisation is table-tested against inputs a user would produce (`♪ = 168`
  in 7/8, `♩ = 120` in 4/4, minim units), asserting the property the trend
  needs: every stored tempo is comparable with every other.
- Mutation-test by **deleting** the normalisation and the pattern gate, not by
  inverting them.

## Coverage

Tier 3. Expected gaps: `ios/` is excluded from Codecov, so PRs 1, 2, 4 and 6
report little; the core PRs (3 and 5) should clear 70% on the handler, migration
and normalisation paths.

## Copy

**Settled (Jon, 2026-09-02): `Passes`, `Got it`, `Not quite`.**

The header becomes **Passes**, not Repetitions: Jon's own word on #1367 and a
musician's rather than a data model's (tone rule 2).

**Both buttons change.** `Clean` and `Missed` were mismatched in kind: `Clean`
described the pass, `Missed` described the player, and you miss a note rather
than a pass.

- **`Got it`** is already this app's own word. The core event is
  `SessionEvent::RepGotIt` and `RepCounter`'s accessibility hint says "bank a
  clean repetition", so the screen has been saying `Clean` over an event called
  `RepGotIt` since the builder era. This aligns them.
- **`Not quite`** narrows nothing: it covers slipped notes, rushing, stiffness
  and stopping dead alike, and it is kind without being soft.
- **`Not quite right`** is the same label at accessibility sizes, where the pair
  stacks and the button goes full width. Two lengths for one label is the
  technique the coach-era `TapVerdict` used (`missedTitleCompact` /
  `missedTitleRegular`); it is recoverable from 071b85b.

Both halves are the same length and register, so neither is easier to press than
the other. That symmetry is the point: a pair weighted toward the gentle option
biases the tap and skews the count low.

Rejected: `Fluffed` (jokey for a button pressed twenty times a session, and it
narrows the cause to slipped fingers); `Nailed it` (a US idiom where British is
mandated, and it overclaims a routine `+1`); `Clean / Not clean` (symmetrical
but dead); `Solid / Scrappy`; `Clean / Rough`.

## Open questions

- **Compound metre display.** 6/8 renders as six cells grouped 3+3, which is
  correct, but the app has no notion that a dotted crotchet is the felt beat.
  Showing `♩. = 56` alongside `♪ = 168` is a later refinement.
- **The trend's axis label.** Once a session can be practised in quaver units,
  the trend chart draws crotchet-normalised values while the player showed
  something else. The chart must name its unit; whether it should also offer the
  reading the user saw is not settled.
- **An accent timbre.** Deliberately out of scope: a second click sound is a
  different question from which beats sound at all, and mixing them makes this
  round untestable by ear.
- **The click keeps running when backgrounded** shipped under #1399: the audio
  background mode keeps the engine rendering, and the stranded-clock guard
  reads wall-clock lag rather than beats. The indicator cannot animate in the
  background; it reads the grid on return, so it comes back in step.
