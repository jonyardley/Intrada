# SessionBlock grouping — spec

> **⚠️ Historical record.** Parked by the 2026-07 coach pivot, which was
> reversed on 2026-08-13 (#1344); the surface it describes returned with the
> restored session builder. Describes shipped behaviour; verify against the
> code before extending.

> Tier 3 (Crux core + FFI bridge + local persistence). Status: **shipped**
> via #1022. The §7 open questions were answered in implementation, so read
> `group_id`, `UngroupBlock` and `UngroupAllBlocks` in `domain/session.rs`
> rather than §7 for what the app actually does.

## 1. Problem

Related exercises are a list on the piece-detail screen today, but they don't
flow into practice. The design ("Where related items travel together · Session
builder") makes them useful: **adding a piece to a session pulls its related
exercises in as one movable block**, so a piece and the work that supports it
never drift apart.

## 2. Target behaviour (from `design/Linked Exercises.dc.html`)

- Adding a **piece** that has related exercises creates a **block**: the related
  exercises sit **before** the piece (warm-up → piece reading order).
- The block **drags as a unit**; rows are **sortable within** the block; the
  block **collapses to one line** (`"Clair de Lune · 2 related, then piece · 18 min"`).
- **Removal granularity:**
  - remove a single row → drops just that exercise from *this* session (it stays
    related to the piece for next time — the link is untouched);
  - block action **"just the piece"** → drop the related, keep the piece;
  - block action **"ungroup"** → dissolve the block, items stay as standalone;
  - global **"Ungroup all"**.
- Directly-added **exercises** stay **standalone** (no block).
- Builder summary: `"32 min · 3 blocks · 5 items"`.

## 3. Current state (see also the architecture map)

- `SetlistEntry` is a **flat** record (`domain/session.rs:56`); `BuildingSession.entries:
  Vec<SetlistEntry>` (`session.rs:103`). No grouping metadata.
- `SessionEvent::AddToSetlist { item_id }` (`session.rs:570`) creates **one** entry
  and **ignores** `linked_exercise_ids`. `RemoveFromSetlist`/`ReorderSetlist`
  operate per-entry (`session.rs:618`, `:637`).
- Relations live on the item: `Item.linked_exercise_ids: Vec<String>` (`domain/item.rs:54`),
  projected as `LibraryItemView.linked_exercises` (`model.rs:257`) — **unused** by the builder.
- ViewModel: `BuildingSetlistView { entries, item_count, … }` (`model.rs:352`),
  `SetlistEntryView` (`model.rs:289`) — no group metadata.
- A built session flattens to `ActiveSession` → `PracticeSession` for persistence;
  entries are flat throughout.

## 4. Approach — `group_id` tag on flat entries (recommended)

Keep `entries: Vec<SetlistEntry>` **flat** and add an optional group tag, rather
than restructuring into nested blocks. A block is a **contiguous run of entries
sharing a `group_id`** (related exercises first, piece last). Standalone items
have `group_id == None`.

**Why this over nested `Vec<SetlistBlock>`:** the flat list flows unchanged into
`ActiveSession`, `PracticeSession`, and persistence — the Active player, Summary,
and the sessions store gain **one nullable field**, not a reshaped model. Grouping
is a building-phase concern projected in the ViewModel. (Nested blocks would ripple
through every phase and the GRDB schema; rejected.)

### 4.1 Core model

- `SetlistEntry`: add `pub group_id: Option<String>` (`#[serde(default)]`).
- New entries from a grouped add share a freshly-minted `group_id` (ulid).

### 4.2 Events (core owns all logic)

- **Change** `AddToSetlist { item_id }`: when the item is a **piece** with
  `linked_exercise_ids`, the handler also appends entries for those related
  exercises (related-first, piece-last), all sharing a new `group_id`. Adding an
  exercise, or a piece with no relations, stays a single ungrouped entry.
  *(Open Q 7.1: dedupe a related exercise already in the setlist.)*
- **New** `KeepOnlyPiece { group_id }` — drop related entries, keep the piece
  (piece becomes standalone: `group_id → None`).
- **New** `UngroupBlock { group_id }` — clear `group_id` on the run; items stay,
  in place, as standalone.
- **New** `UngroupAllBlocks` — `UngroupBlock` for every group.
- **New** `RemoveBlock { group_id }` — remove the whole block (piece + related).
- **Reuse** `RemoveFromSetlist { entry_id }` for single-row removal (unchanged;
  does **not** unlink — the relation is on the item, not the entry).
- **Reorder:** `ReorderSetlist` stays for *within-block* moves (must keep the run
  contiguous — reject/clamp a move that would split a group). Add
  **`ReorderBlock { group_id, new_position }`** to move a whole block as a unit.

### 4.3 ViewModel projection

Extend `BuildingSetlistView` additively (keep `entries` so the paused web shell
keeps compiling — invariant 6):

- add `blocks: Vec<SetlistBlockView>` where
  `SetlistBlockView { group_id: Option<String>, piece_title: Option<String>,
  related_count: usize, duration_display: String, entries: Vec<SetlistEntryView> }`
  (a standalone item = a one-entry block with `group_id: None`).
- add `block_count: usize` to drive `"3 blocks · 5 items"`.
- `SetlistEntryView` gains `group_id: Option<String>` for within-block affordances.

The core computes block summaries; the shell renders. **Collapse state is UI-only**
(SwiftUI `@State` / Leptos signal) per the state-boundary table — never core state.

### 4.4 Persistence / offline-first

- `group_id` rides the flat entry into `ActiveSession`/`PracticeSession`.
- Sessions persist their entries as a **JSON blob** through the `StoredEntry` DTO
  (deliberately not bincode, so field additions are safe — `LibraryStore.swift`).
  So **no SQL migration**: add an optional `groupId` to `StoredEntry` + the
  encode/decode mapping; old rows decode it as `nil`. Core type + DTO + codec
  evolve together.
- No new network path; pure local mutation. Invariants 1–8 hold (no hard delete,
  reconciliation stays in core, both modes branch-free here).

### 4.5 UI (SwiftUI)

- Builder queue renders `blocks`: a block gets a header row (piece title + `N
  related, then piece · MM min`, collapse chevron, overflow menu → "Just the
  piece" / "Ungroup") over its entry rows; standalone items render as today.
- Block header is the drag handle for `ReorderBlock`; within-block rows reorder
  via the existing per-row handle (clamped to the group).
- Toolbar gains "Ungroup all" when any block exists.
- Reuse `SetlistQueueRow`; add a `SessionBlockHeader` primitive.

## 5. Key decisions

- **Flat entries + `group_id` tag**, not nested blocks (§4).
- **Default = bring related**; "just the piece" is the escape hatch (matches design).
- **Removing a row never unlinks** — the relation lives on the item.
- **Collapse is UI-only**; block structure + summaries are core-projected.
- **Additive ViewModel** (`entries` retained) so the paused web shell still builds.

## 6. Phasing

- **Phase A** (this spec rides here): core model + events + ViewModel projection +
  round-trip tests + persistence codec (no SQL migration — see §4.4) + binding
  regen + preview-literal fixes. No new builder UI yet; web unchanged.
- **Phase B**: SwiftUI block rendering, reorder-as-unit, block actions, snapshots.
- **Phase C**: polish — collapse animation, "Ungroup all", a11y, iPad.

## 7. Decisions (resolved for Phase A)

1. **Dedupe:** a related exercise already in the setlist is **skipped** — never
   duplicated (it stays where it is; the new block just omits it).
2. **"Ungroup" vs "Remove block":** **both** kept — `UngroupBlock` keeps the items
   (clears `group_id`), `RemoveBlock` drops the whole block.
3. **Reorder model:** whole-block drag (`ReorderBlock`) + within-block drag
   (`ReorderSetlist`, contiguity-guarded). Dragging a row *out* of a block is
   deferred to Phase C.
4. **Piece removal dissolves the block:** removing the *piece* via
   `RemoveFromSetlist` clears `group_id` on the remaining related (they become
   standalone) — a block only means "this piece's warm-up". Implemented via
   `dissolve_pieceless_groups`; tested.

## 8. Risks

- **Bridge round-trip:** `group_id` + the new events cross the bincode FFI bridge.
  Extend `assert_round_trips` for every new event/field **before** wiring UI
  (the #846 silent-no-op class). Plain `Option<String>` is bincode-safe; no
  JSON-only serde attrs.
- **Reorder contiguity:** the invariant "a group is a contiguous run" must be
  enforced in every reorder handler, with a test that a split-causing move is
  rejected.
- **Web compile:** additive ViewModel keeps `intrada-web` building; CI still runs it.
