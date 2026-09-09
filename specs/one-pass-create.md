# Adding a piece in one pass

> Tier 3 by domain sensitivity: a new event crosses the FFI bridge and carries
> a nested create. Issue [#1390]. [#1080] ("add a lesson") closes into this: the
> decision of 2026-09-07 (Stage 4 of [`rethink-plan.md`](../docs/rethink-plan.md))
> is that the fast path through existing primitives *is* the answer to the
> lesson-capture shape question, and no lesson entity gets built. **Scope:
> `intrada-core` + native iOS only.** API/Turso out of scope.
>
> Two PRs: core first, reviewed before the screens start (CLAUDE.md Workflow,
> bridge-shape rule). This spec is the first commit on the core branch.
>
> Design conversation (Claude Design) before the screens PR. The layout below
> is the constraint set that pass works inside, not a finished mock.

[#1390]: https://github.com/jonyardley/intrada/issues/1390
[#1080]: https://github.com/jonyardley/intrada/issues/1080
[#1387]: https://github.com/jonyardley/intrada/issues/1387
[#1363]: https://github.com/jonyardley/intrada/issues/1363
[#1389]: https://github.com/jonyardley/intrada/issues/1389
[#1108]: https://github.com/jonyardley/intrada/issues/1108
[#1595]: https://github.com/jonyardley/intrada/issues/1595

## Problem

A lesson gives you a tune and the three to five exercises that build it.
Adding that to the app takes one trip through the create form, then a second
trip to the piece's detail screen for the chord chart, then a third for the
exercises. Nothing on the create form says the chart or the exercises are
possible, so the second and third trips depend on having found them once
before.

`ItemFormScaffold` collects title, kind, composer, key, modality, tempo, notes
and tags (`ios/Intrada/Views/Screens/ItemFormModel.swift`), and sends
`ItemEvent::Add(CreateItem)`. The chart lives behind `ChordChartEditSheet` on
`LibraryDetailScreen`; related exercises live behind the picker and the
write-your-own action on the same screen.

There is a sharper version of the same gap in the photo path.
`PhotoDraft.chart_text` exists in the core, survives the substring clamp, and
round-trips across the bridge with `"F7 | Bb7"` as its pinned fixture
(`crates/intrada-core/src/domain/recognition.rs:87`, `:249`). `LibraryAddScreen`
reads it to decide whether the page read nothing. The form has nowhere to put
it, so a chart read off a page would be dropped on the floor. Phase D of
[`piece-from-photo.md`](piece-from-photo.md) fills that field; this spec builds
the half that catches it.

## What is already built

Named so this does not get re-derived, and because it changes the size of the
work.

- **`ItemEvent::AddLinkedExercise { piece_id, input }`**
  (`domain/item.rs:114`, handler `:398`) mints an exercise and links it in one
  event so it can never land unlinked (#1431). Refuses in online mode with
  "Related exercises aren't available online yet"; writes one `SaveItems`
  batch; five behaviour tests plus two real-bridge round-trips.
- **`ItemEvent::SetChordChart`** (`:644`) calls `parse_chart` and saves; the
  sheet stays open on a parse error showing the offending token (#846).
- **`ItemEvent::CommitScaffold { piece_id, kinds }`** (`:746`) re-derives
  exercises from the stored chart, deduplicates against what is already linked,
  and mints the selected ones.
- **The reverted one-pass event.** `ItemEvent::AddPieceWithScaffold { piece:
  CreateItem, scaffold: Vec<ScaffoldEntry> }` from #1091, reverted in #1092
  because the *screen* shape was in doubt, not the event. Recover with
  `git show d683a790`: `ScaffoldEntry::New(CreateItem) | Existing { id }`,
  local-first only, validate-everything-before-mutating, one `SaveItems`
  (exercises then piece), ten tests including an FFI round-trip.

So the transactional machinery has been written once and proven once. What was
missing was the surface, which is what #1390 is.

## Approach

One event, one save, and the create form grows two optional sections.

### Key decisions

1. **A new event, not a wider `CreateItem`.** `CreateItem` is shared with
   `AddLinkedExercise`, so a `chart` field on it would let an exercise carry a
   chord chart and would give the nested create its own nested create. The
   one-pass path gets its own variant and `CreateItem` is untouched.

2. **Recover the reverted handler rather than write a third one.**
   `AddPieceWithScaffold`'s semantics were right: validate the piece, every new
   exercise and every existing id *before* mutating anything, then one batch.
   The chart is the only addition.

3. **The chart crosses as raw text and is parsed inside the event.** The core
   owns interpretation (`parse_chart` needs the key, modality and metre the
   same event is carrying). A parse error rejects the whole create and writes
   nothing, so there is no half-made piece to clean up, and the error is the
   existing per-token message.

4. **The exercises captured here are the musician's own, not the derived
   five.** Chart-derived suggestions stay where T18 put them: in the Related
   exercises card on the piece, offered after the piece exists, proposed rather
   than prescribed. Generating them at create time would make the app write
   five library items before the musician has seen the piece save once.

5. **`ChordChartEditSheet` gains a text-returning mode; it is not cloned.**
   On the create path there is no piece id to send `SetChordChart` to, the same
   shape as phase B's `ReadPhoto` taking only a `photo_id`. The sheet keeps its
   editor, its format hint and its reconstruction helper; the caller decides
   whether the text goes to an event now or waits for Add.

6. **Live parse feedback is out of scope.** On the create path the chart is
   parsed when Add is pressed, and the error lands in the chart section rather
   than only the form banner. Per-bar feedback while typing is [#1387] part 1
   and stays there.

7. **Local-first only, matching `AddLinkedExercise`.** In online mode the
   event refuses with the existing message rather than half-applying. The app
   is offline-first; online mode is the legacy path.

8. **A photo-read chart fills the section like any other read field.**
   `ItemFormModel.ReadField` gains a `chart` case, so a second scan replaces
   what the first wrote and typing takes the mark off. This is the only change
   phase D then needs on the shell side.

## The contract

```rust
// crates/intrada-core/src/domain/item.rs

ItemEvent::AddPieceInFull {
    piece: CreateItem,
    /// Raw text, exactly what `SetChordChart` takes. Parsed in the handler
    /// against the piece's own key, modality and metre.
    chart: Option<String>,
    exercises: Vec<ScaffoldEntry>,
}

/// Recovered verbatim from d683a790.
pub enum ScaffoldEntry {
    New(CreateItem),
    Existing { id: String },
}
```

Handler order, and all of it before any mutation. The first failure wins:
`last_error` is a single slot, so a create carrying both a bad bar and a blank
exercise title surfaces the title, and the screens have to cope with only one
of the two being pointed at.

1. Refuse online, but only when a chart or an exercise is present. A bare
   piece is an ordinary create and falls through to `ItemEvent::Add`, rather
   than being refused in the name of two things the musician never used.
2. Validate the piece through the existing create validation.
3. Validate every `New` title and resolve every `Existing { id }` to a real
   exercise. An unknown id or a blank title rejects the event. A repeated id
   is collapsed rather than rejected, matching `CommitScaffold`.
4. Parse the chart, if present. A `ChartParseError` rejects the event. Text
   that is empty or only whitespace counts as no chart, never a parse error:
   unlike `SetChordChart` there is no separate clear on this path.
5. Mint ulids for the piece and each new exercise, set the piece's
   `linked_exercise_ids` and `chord_chart`, then emit **one** `SaveItems`.

Wire constraints:

- `Item`'s appended `#[serde(default)]` tail (`linked_exercise_ids`,
  `chord_chart`, `variants`, `photo_id`, `metre`) is unchanged. No new field on
  any existing type, so nothing shifts position.
- `ActiveSession` is untouched: `SetlistEntry` denormalises item fields rather
  than embedding `Item` (`domain/session.rs:63`), so the crash-recovery blob
  graph does not see this. Re-verify if that ever changes.
- The new event and `ScaffoldEntry` need `assert_round_trips` entries beside
  the other item-event round-trips in `domain/item.rs`, and a real-bridge
  round-trip in `StoreEffectLoopTests`, before any screen sends them: a stub
  bridge cannot catch a wire break (#846).

Against the offline-first checklist: no `Http` on the local path (invariant 1),
client-minted ulids (3), all interpretation in the core (4), a failed write
surfaces rather than faking an ack (5), local-first only and consciously scoped
(6).

## The screens

The minimal form stays minimal (principle B, progressive disclosure). Two
collapsed rows sit below the existing fields, each expanding in place:

- **Chord chart** opens the existing sheet and comes back with text. A chart
  read from a photograph arrives already filled and marked as read.
- **Related exercises** offers writing one and choosing existing ones,
  reusing `LinkedItemPickerSheet` and the same two actions the piece's Related
  exercises card carries. Rows are removable before saving; nothing is written
  until Add.

Wording is settled at the Claude Design pass against the words already on the
detail card, so the two surfaces agree rather than inventing a second
vocabulary. Both sections are silent when empty: no counts, no "optional"
captions.

## Pointing at the failure

Follow-on phase, issue [#1595], and the reason the screens above ship the
banner alone. `ViewModel` carries `error` and `error_seq` and nothing else
about a failure, so the two commonest cases are indistinguishable from Swift:
a blank piece title and a blank staged exercise title both come out of
`validate_title` as the same sentence, and matching the chart's `Bar 4: ...`
on message text would put domain logic in the shell.

So the core says where, and the shell points:

```rust
// crates/intrada-core/src/model.rs

pub enum FormErrorTarget {
    Piece { field: FormField },
    /// 1-based bar, 0 for the chart as a whole; `token` is what the parser
    /// stumbled on, both already carried by `ChartParseError`.
    Chart { bar: usize, token: String },
    /// By position in the `exercises` the event carried. `field` is `None`
    /// when the row is a chosen exercise rather than a written one.
    Exercise { index: usize, field: Option<FormField> },
}

pub enum FormField { Title, Composer, Tempo, Notes, Tags }
```

`ViewModel::error_target` is `Some` only while the error it belongs to is the
one the event just set. `App::update` clears the model's copy before every
event, so a target cannot outlive its message or point at a row the musician
has since changed: every path other than `AddPieceInFull` sets an error and no
target, which reads as the banner alone, exactly as today.

### Key decisions, continued

9. **The target is a place, not a second verdict.** It names the section, the
   row by index, and for a chart the bar and the offending token. The wording
   stays the core's one sentence: the shell renders it in the banner and marks
   the spot, it never composes a message of its own.

10. **A field the form cannot show gets no target.** `validate_create_item`
    can fail on `photo_id`, which is nothing anyone can fix in place, so the
    field mapping is fallible and an unmapped field falls back to the banner.

11. **One failure at a time stays.** Validation still stops at the first
    error, so a form with two problems takes two presses. Collecting them all
    would change every other caller of `validate_create_item`, and the screen
    would still only point once.

## Tests

- The whole-event property: a bad chart, a blank exercise title or an unknown
  existing id leaves `model.items` exactly as it was.
- One `SaveItems` batch, not one per item.
- The piece is saved already carrying its links and its chart, so no second
  event is needed to make it whole.
- Round-trips as above, before the screens exist.
- Snapshots: the form with both sections collapsed, and with a chart and two
  exercises staged.
- Each target case, with the failure on the second row so a target that always
  names the first one fails: the piece field, a written row, a chosen row that
  has gone, and the chart's bar and token.
- The invariant: an error set by any other event reports no target, and a
  create that then succeeds stops pointing.

## Open questions

1. Does the edit path get the same sections, or does the piece detail stay the
   place to change a chart? Held: create is where the material is fresh.
2. What happens to an exercise staged but not saved when the create fails? The
   draft is shell state, so it survives on screen; that needs saying in the
   design pass rather than discovered.
3. Whether "Related exercises" is still the right words once [#1363]
   (many-to-many links) and [#1389] (what counts as an exercise) are settled.
4. Whether the scaffold's non-atomic online path ([#1108]) is worth fixing at
   the same time, or stays a separate debt.
