# Picker core sort: delete the Swift copy

> Tier 3 (Crux core + FFI bridge change). Spec rides with the core PR per
> CLAUDE.md. Native iOS only.

## Problem

The exercise/piece picker sheet (`LinkedItemPickerSheet`) filters and sorts its
own candidate list rather than the core's shared Library `ListQuery`,
deliberately: using the Library's query would mutate state the Library screen
itself reads, so a tap in the picker must never disturb it (see the sheet's own
header comment). To keep the sheet independent, two functions were written in
Swift as copies of core logic: `sortedLikeTheLibrary` mirrors
`sort_library_items` and `title_sort_key` (`app.rs`, and see `library-sort.md`
for the sort design itself); `matchesSearch` mirrors the text-match half of
`apply_query_filter`. If the core's rule changes, the picker silently
disagrees with the Library screen until someone remembers the copy, which is
the exact failure #1445 was.

## Target state

The core owns the comparator and the text match; the picker still curates its
own subset, independently of the Library's `ListQuery`, but by calling the
core rather than reimplementing it.

## Approach: a plain FFI call, not an Event

The picker re-filters on every keystroke and every tag/priority toggle. Routing
that through the standard `Event` → `Effect::Render` → `ViewModel` loop would
mean bincode-encoding the full candidate set on every keystroke and reading it
back through a ViewModel field that exists for no other reason. A plain,
synchronous `uniffi::export` function outside the event loop is the
established shape for exactly this kind of problem in this codebase (a pure
calculation with no state, no persistence and no network, called directly
rather than through the event loop): `page_outline_fault` (PR #1660, deleted
with page cropping in #1684) was the other instance of it.

### Core (`intrada-core`)

A minimal candidate type carrying only the fields the comparator and the text
match actually read, not the full 18-field `LibraryItemView`, so the FFI
surface does not grow every time an unrelated field is added to the library
item:

```rust
pub struct PickerCandidate {
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub notes: Option<String>,
    pub tags: Vec<String>,
    pub created_at: String,
    pub last_practiced_at: Option<String>,
}

pub fn sort_and_filter_candidates(
    candidates: &[PickerCandidate],
    sort: &LibrarySort,
    search: &str,
) -> Vec<String> // ordered, filtered ids
```

`sort_library_items` and `apply_query_filter`'s text-match block are rewritten
to call the same comparator and predicate this function uses, so there is one
implementation of "how the library sorts" and "what a search matches", not
two. `LibrarySort`, `SortField` and `SortDirection` are unchanged, reused
directly from `domain/types.rs`.

One divergence from `apply_query_filter`, deliberate: `sort_and_filter_candidates`
trims the search text before matching (`search.trim().to_lowercase()`),
matching the Swift `matchesSearch` behaviour it replaces. `apply_query_filter`
does not trim `query.text`. The predicate the two share is identical; only the
query normalisation differs, and only because the picker's existing UX already
depended on it.

Returning **ids to reorder by**, not full items, is the load-bearing choice:
the FFI-side type mirroring `PickerCandidate` needs `uniffi::Record`, which
`intrada-core`'s domain types never carry (core stays UniFFI-agnostic, per
CLAUDE.md's crate boundaries), so crossing the plain-call boundary always
needs a small duplicate type on the `intrada-ffi` side. Sending ids keeps that
duplicate to 7 flat fields regardless of how many fields `LibraryItemView`
carries; sending full items would mean mirroring all 18, including nested
types (`ItemPracticeSummary`, `LinkedExerciseView`, `ExerciseUsageView`), which
is worse duplication than the two Swift files this issue deletes.

### FFI (`intrada-ffi`)

```rust
#[derive(uniffi::Record)]
pub struct PickerCandidateArg { /* mirrors PickerCandidate, 7 fields */ }

#[derive(uniffi::Record)]
pub struct PickerSortArg { pub field: PickerSortField, pub direction: PickerSortDirection }

#[derive(uniffi::Enum)]
pub enum PickerSortField { DateAdded, LastPracticed, Title }

#[derive(uniffi::Enum)]
pub enum PickerSortDirection { Ascending, Descending }

#[uniffi::export]
pub fn sort_and_filter_picker_candidates(
    candidates: Vec<PickerCandidateArg>,
    sort: PickerSortArg,
    search: String,
) -> Vec<String>
```

`From`/`Into` conversions to the core types. `From<SortField> for PickerSortField`
is exhaustive over the core enum, so a fourth `SortField` variant is a compile
error here rather than a silent gap the picker cannot express.

### Swift (screens PR)

`LinkedItemPickerSheet.filtered` builds `[PickerCandidateArg]` from `available`
(mapping the 7 fields), calls the new bridge function with `sort` and
`searchText`, and reorders `available` by the returned id list.
`priorityOnly` and the tag filter stay exactly where they are today, since
those are genuinely shell-local UI state, not core logic.
`LibraryItemView+Sort.swift`, `LibraryItemView+Search.swift` and their two
test files (`LibraryItemSortTests.swift`, `LibraryItemSearchTests.swift`) are
deleted.

## Key decisions

1. **Plain FFI call, not an `Event`.** No state, no persistence, no network;
   avoids a per-keystroke bincode round trip through the ViewModel.
2. **Return ids, not full items.** Keeps the FFI-side duplicate type small and
   stable; the alternative duplicates all 18 `LibraryItemView` fields plus
   three nested types.
3. **One shared comparator/predicate in the core**, called by both
   `sort_library_items`/`apply_query_filter` and the new picker function, not
   a second core copy sitting next to the first.
4. **Tag filter and `priorityOnly` stay in Swift.** They are picker-only UI
   state today with no core equivalent; only the two functions that already
   exist in the core (sort, text search) move.
5. **Two PRs, core first** (CLAUDE.md's bridge-shape rule): the core PR ships
   `PickerCandidate`, `sort_and_filter_candidates` and the FFI export with
   Rust tests; the screens PR wires the sheet to it and deletes the Swift
   copies. The core PR is not shell-dead in the meantime: the new function is
   called directly, not through a ViewModel projection, so nothing downstream
   needs it to compile.

## Deliberately not doing

- **Moving `priorityOnly` or the tag filter into the core.** No duplication
  risk today, since the core has no equivalent logic to drift from.
- **A generic "core filter/sort" trait or engine.** One picker, one call;
  reconsider only if a second picker-shaped consumer appears.
- **Changing the Library screen's own `ListQuery` path.** Untouched by this
  change.
- **Trimming `query.text` in `apply_query_filter`.** Would change the
  Library's own search behaviour, which nobody asked for; see the divergence
  note above.

## Testing

- **Core (TDD):** `sort_and_filter_candidates` matches `sort_library_items`
  and the text-match block field-for-field, including the properties the
  deleted Swift test file pinned (ties resolve newest-first then id, the
  tiebreak ignores sort direction, case-insensitive title order in both
  directions, accented titles file under their base letter, a never-practised
  item sorts before an older practised one); empty search returns everything
  in sort order; a search matching nothing returns an empty list; an
  equivalence test pins that `sort_library_items` plus `apply_query_filter`
  and the new function agree on the same input, including a tie and a text
  filter, not just a single trivial element; `sort_library_items`/`apply_query_filter`
  still pass their existing tests after the refactor.
- **FFI:** a round-trip test through the FFI-side duplicate types; a table
  test covering every `PickerSortField` and `PickerSortDirection` combination
  through the `From` conversions, not only `Title`/`Ascending`.
- **iOS (screens PR):** `LinkedItemPickerSheet`'s existing behaviour
  (filtering, sorting, tag/priority toggles) still passes its current tests,
  now driven by the bridge call instead of the deleted Swift functions.
