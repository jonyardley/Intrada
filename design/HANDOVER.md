# Handover — Linked Exercises &amp; design-system reconciliation

_Session summary. What changed, where it lives now, and how to keep it that way._

---

## 1. What this session delivered

**Feature designed: "Related exercises"** (formerly "linked exercises") — a piece links
to the exercises practised alongside it, surfaced on the piece detail, threaded into the
session builder, scored with a new 0–10 ring, and reflected on at session hand-off.

**Plus a full design-file reconciliation** so there is now one canonical home per screen
and component, and a written process to keep it that way.

---

## 2. New / changed components (all now in the design system)

| Component | What it is | Notes |
|-----------|-----------|-------|
| **ScoreRing** | 0–10 mastery score — monochrome arc + centred numeral | Replaces the old 5-step MasteryMeter bars and the score dots. Value encoded twice (arc + numeral) = colour-blind safe. `0` = empty ring + en-dash. |
| **ScoreSelector** | 1–10 tap pills, cumulative fill | Sets the score; feeds the ring everywhere. |
| **RecentSessions** | ring + date + reflection-note rows, with a `5 → 7` trend chip | On piece &amp; exercise detail to show progress. |
| **Related-exercises card** | piece-detail card: rows (gold bar + title/meta + ring) + "Add a related exercise" | Empty / populated / edit states. |
| **SessionBlock** | a piece + its related exercises as one movable block | Include toggle + drag handle per row; collapses to a one-liner. |
| **Add/remove picker** | one searchable list that adds *or* removes related items | Already-related shown selected; "Done". Built on TagFilterSheet chrome. |
| **Library header** | star · `All ▾` dropdown · sort · filter · search, with a bottom divider/shadow | Replaced the old All/Pieces/Exercises pill row. |
| **Delete button** | outlined cream + red text + trash | New default destructive style. |
| **Add-item button** | dashed full-width "+ Add …" | New default add style. |
| **Exercise badge** | now uses the **dumbbell** icon (was `repeat`) | Applied app-wide. |

Library rows also gained a **genre tag chip** and a **purple star** (inline with the tag) for favourited items.

---

## 3. File organisation now in place

- **`Intrada Design System.dc.html`** — canonical. Foundations + components + the four
  pillar screens (Library, Practice, Routines, Progress) + Add piece. Item detail is a
  **link** to the feature file. Focus player & Session summary are **imported** (below).
- **`Linked Exercises.dc.html`** — the Related-exercises **journey** only: piece-detail
  states (empty / populated / edit), exercise detail, both pickers, session builder
  (add → group → swipe/edit remove), focus reflection.
- **`Focus Player.dc.html`** / **`Session Summary.dc.html`** — shared screens extracted
  to their own importable DCs, mounted via `<dc-import>` in both the system and the
  feature file. **One definition, edited once.**
- **`Intrada Concepts.dc.html`** — explorations only (after-dark dark-mode proof + live
  motion lab). All duplicated shipped screens removed.
- **`design-process.md`** — the file-organisation + sync rules (incl. §9 the import
  pattern + migration status). **`CLAUDE.md`** points at it as READ-FIRST.
- Deleted the stale `design_handoff_engaging_refresh/` snapshot (was drifting).

---

## 4. Key decisions made

- **Score:** 0–10 ring chosen over bars/dots; monochrome; `0` = empty ring + en-dash.
- **Copy:** "linked" → **"related"** everywhere; "warm-up" wording dropped; add button =
  "Add a related exercise".
- **Picker:** the **add/remove manager** (variant B) is canonical; it shows already-related
  items rather than hiding them.
- **Session builder:** related items travel as a **group**; one removal action (swipe or
  edit) — no separate per-item "skip today" toggle; rows sortable within the group.
- **Reflection at hand-off:** ScoreSelector + free-text note (the score ring was removed
  from the sheet as redundant with the selector).
- **Light theme only** for MVP (unchanged); dark stays parked in Concepts.

---

## 5. How to keep it aligned (every iteration)

1. New/changed component → promote to the design system (and `Theme.swift` if a token changed).
2. Pillar screen changed shape → update it once in the DS.
3. Screen shown in 2+ files → extract to its own `<Name>.dc.html`, `<dc-import>` it, delete inline copies.
4. Pull from the **latest** source (the feature file), not the system's older copy.
5. Never draw a screen twice — link or import instead.
6. Run the checklist in `design-process.md` and record winning-design decisions in the spec.

---

## 6. Open follow-ups (not blocking)

- Extract the remaining single-home pillar screens (Library, Practice, Routines, Progress,
  Add piece) to importable DCs **when they're first shown in a second file** — not before.
- Optionally convert the Item-detail **link** to an **import** for mechanism uniformity.
- Fold the agreed components/tokens into `Theme.swift` (code remains canonical for tokens).
- Minor, undocumented-by-choice: the reflection note field + the "Related to [piece]"
  provenance breadcrumb (standard input / tiny inline pattern).
