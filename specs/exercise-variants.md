# Exercise steps (variants)

> **⚠️ Historical record.** Parked by the 2026-07 coach pivot, which was
> reversed on 2026-08-13 (#1344); the surface it describes returned with the
> restored session builder. Describes shipped behaviour; verify against the
> code before extending.
>
> **Decisions 4 and 5 are superseded** by
> [`exercise-variations.md`](exercise-variations.md) (#1739): the current-rung
> concept is gone, and a session entry holds a list of plays rather than one
> score, one tempo and one variant.

> Tier 3 spec. Issue [#1083] (epic [#1087], workstream C). Landed in two
> passes: PR #1112 (schema slice: `Variant` type, `Item.variants`,
> `SetlistEntry.variant_id`, GRDB `v9_variant` child table + codecs) and
> PR #1118 (the mechanism: whole-ladder reconciliation, entry attribution
> validation, per-step derivation, local-first gating; this document
> unified). C2 (Steps UI + reflection picker), C3 (12-keys preset, closes
> #46) and C4 (step management polish) follow as their own PRs. **Scope:
> `intrada-core` + native iOS only**; web/API (Turso) out of scope until
> sync. Users see **"Steps"** (or "Keys"); "variant" is the core's name and
> never appears on screen. Per-step state reads **"Solid"**, never
> "consolidated".

[#1083]: https://github.com/jonyardley/intrada/issues/1083
[#1087]: https://github.com/jonyardley/intrada/issues/1087

## Problem

"Land on the 3rd, then add a note each round" is a ladder. So is "all twelve
keys", and so is "shells in each inversion". Today an exercise has one flat
score, so progress along any of these reads as noise: score 8 in C says
nothing about F♯. Multi-key practice (#46) and the chart-to-scaffold twelve-key
ladder ([#1107], a blocked consumer) both need the same thing: an exercise
that owns an **ordered list of variants, each scored independently**, where
progress means advancing the step, not polishing one rating.

## Approach

One generic mechanism, no per-preset code. An exercise owns
`Vec<Variant>`; a variant is `{ id, label, position, updated_at, deleted_at }`.
Session entries gain an optional `variant_id` recording *which step* they
practised. Everything else is derived: per-step score history, whether a step
is **solid**, and the **current step** (the first that isn't yet solid).
Presets (twelve keys, inversions) are just label lists; C3 ships the first.

```text
Item (exercise)
  └─ variants: Vec<Variant { id, label, position, updated_at, deleted_at }>
PracticeSession
  └─ entries[]: SetlistEntry { …, variant_id: Option<String> }   // serde(default)
ViewModel
  └─ LibraryItemView.variants: Vec<VariantView { …, latest_score,
       score_history, is_solid, is_current }>
  └─ SetlistEntryView.variant_id
```

## Key decisions

1. **Variants embed in `Item` on the wire, but persist to a `variant` child
   table.** `Item.variants: Vec<Variant>` (`#[serde(default)]`, trailing)
   keeps the model/bridge shape simple and makes every save atomic with the
   item row; the GRDB store fans the list out to per-row storage. The child
   table (the store's first normalized one; every prior one-to-many is a JSON
   column) exists for **per-row LWW**: each step carries its own `updated_at`
   + `deleted_at`, so the future sync engine can merge a rename on device A
   against an archive on device B without whole-item conflicts (invariant 2).
   The usual reason the app avoids child tables (positional bincode breaking
   old rows) doesn't apply: SQL columns aren't positional.
2. **No hard deletes; tombstones stay in the model.** Removing a step sets
   `deleted_at`; the row stays in the table *and* in `Item.variants` (views
   filter it). Kept in-model so (a) the core owns reconciliation; the shell
   never diffs child rows (invariant 4), and (b) history keeps resolving: a
   session entry pointing at a removed step still finds its label.
   (Supersedes #1112's shell-side `deleted_at IS NULL` load filter, which
   would have made resurrection impossible; no tombstones existed in the
   wild before the flip.) Note for C4's drag-reorder: tombstones keep their
   stale `position`, which can collide with a live step's; nothing may
   assume positions are unique across the mixed list, only among live steps.
3. **Two write events, one reconciliation engine.**
   - `ItemEvent::SetVariants { id, labels }` defines the whole ladder,
     reconciled by case-insensitive label: matches keep their id (and so
     their score history) and adopt incoming casing; removed labels
     tombstone; a re-added label **resurrects** its tombstoned variant,
     history intact. Empty list clears the ladder. A no-op call leaves the
     parent `updated_at` alone and writes nothing (parent-level LWW hygiene).
   - `ItemEvent::AddVariant { item_id, label }` (from #1112) appends one
     step; it is sugar over the same reconciliation (live labels + the new
     one), so it shares validation and resurrects a tombstoned label rather
     than duplicating it.
   Rename is deliberately *not* expressible by label reconciliation
   (indistinguishable from remove+add); C4 adds an id-based rename event.
4. **"Solid" is `latest step score >= 8` (of 10)**; `SOLID_SCORE_MIN` in
   `domain/variant.rs`. Top fifth of the scale, a named constant rather than
   a per-user setting until real use argues otherwise. "Current step" =
   first live step by position that isn't solid; a fully-solid ladder has no
   current step (it's done). Derivation lives in `build_view`, computed per
   render like `exercise_contexts`; never stored.
5. **`variant_id` joins the session-entry codec, not the schema.** Entries
   are a JSON blob in the session row, so old rows decode the missing key to
   `None`; no migration. The core writes it via
   `SessionEvent::SetEntryVariant { entry_id, variant_id }`, valid in every
   phase: Building tags the rung you plan to practise; Active/Summary is the
   reflection attribution. The step must be a **live** variant of the
   entry's item; `None` clears. Scores stay on the entry; the variant says
   which rung they belong to, and per-step history only counts entries that
   actually carry a score. No snapshot label in the entry: labels resolve
   live via decision 2 (revisit only if exercise deletion in history proves
   to matter). Known trade-off: the *crash-recovery* blob (UserDefaults) is
   positional bincode, so this field change invalidates a blob written by
   the previous build; one resume prompt is lost across that upgrade, as
   with `group_id` before it (tracked: #1116).
6. **Local-first only until sync** (epic decision, invariant 6 consciously
   scoped). All three write events surface "Steps aren't available online
   yet" in online mode, mutate nothing, and emit no HTTP; pinned by tests,
   so the scope-out is explicit rather than a silent no-op (#846 class).
   This supersedes #1112's tolerate-online reading: an online write whose
   variants the server silently drops is exactly the silent-loss class the
   principles ban. The API keeps compiling (`variants: vec![]` at its
   construction sites, the `modality` precedent; reads default
   `variant_id: None`); server tables arrive with the sync engine.
7. **Step scope capped: label + position + score history.** No per-step
   tempo, notes or targets in v1; every extra field is a migration on the
   tier where the device is the only copy of the data.

## Validation

- Host item must exist and be an **Exercise** (pieces don't get ladders).
- Labels: trimmed; each 1–`MAX_VARIANT_LABEL` (100) chars; at most
  `MAX_VARIANTS` (24) per ladder; case-insensitive duplicates rejected.
  Empty list = clear the ladder (tombstones every step).
- `SetEntryVariant`: entry must exist (Building, Active or Summary);
  `variant_id` must be a **live** variant of that entry's item; `None`
  clears.

## Persistence (GRDB, migration `v9_variant`, shipped in #1112)

```sql
CREATE TABLE variant (
  id TEXT PRIMARY KEY NOT NULL,
  item_id TEXT NOT NULL,
  label TEXT NOT NULL,
  position INTEGER NOT NULL,
  updated_at TEXT NOT NULL,   -- RFC3339, written by the core (same as item)
  deleted_at TEXT             -- soft-delete tombstone
);
CREATE INDEX index_variant_on_item_id ON variant(item_id);
```

- `save(item)` / `save(items)` upsert every `item.variants` row inside the
  existing transaction (ON CONFLICT(id) DO UPDATE). No delete-missing: the
  core always carries the tombstones it loaded, so absent-row diffing never
  happens in Swift.
- `loadItems()` attaches **all** variant rows (tombstones included) per
  decision 2, ordered by position.
- Deleting an exercise tombstones the item row only; its variant rows stay,
  unreferenced; harmless, and sync-safe.

## Testing

- **Core (TDD):** ladder create / append / reorder-preserves-ids / tombstone /
  resurrect / casing adoption / no-op-skips-save; validation rejections;
  empty-list clear; per-step derivation (latest, history, solid, current);
  entry attribution set/clear per phase + rejections; saved sessions carry
  `variant_id`; online-mode graceful degradation for every write event (no
  mutation, no HTTP, error surfaced).
- **Bridge (#846):** `assert_round_trips` for `Variant`-in-`Item`-in-
  `SaveItem`/`SaveItems`, `SetVariants`, `AddVariant`, `SetEntryVariant`,
  `SetlistEntry.variant_id`-in-`SaveSession`, `VariantView`; plus a real
  `LiveBridge` Swift test driving set-ladder → view → entry attribution
  set/clear through actual bincode.
- **iOS:** `v9` upgrade-path test from a populated v8 DB (rows intact, empty
  ladders); variant save/load round-trip incl. tombstone + ordering; old
  entries blob (no `variantId` key) decodes to `nil`; batch save writes each
  item's ladder (atomicity itself comes from the shared `dbQueue.write`
  transaction, #1106).

## Open questions (deferred, tracked on #1083)

- **C2:** exercise-detail Steps section (per-step rings) + reflection step
  picker (defaults to the current step; never slows the everyday save).
  Reconcile with B's per-piece detail surfaces before build.
- **C3:** 12-keys preset ordering (fifths vs chromatic) and key-grid UI;
  closes #46. #1107's twelve-key scaffold ladder consumes the same preset.
- **C4:** rename (id-based), drag reorder, archive UI on top of the
  already-shipped tombstones.
- Whether `SOLID_SCORE_MIN` should ever be user-tunable, and whether "solid"
  should decay with time (research-foundation.md's consolidation model);
  out of scope until the scheduler epic.
