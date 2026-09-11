# Design in the Intrada workflow

> Replaces the Pencil (`design/intrada.pen`) step. Design now happens in
> **Claude Design**, and the living reference is checked into the repo as HTML.

## What lives where

| Artifact | Path | Role |
|----------|------|------|
| **Token source of truth** | `ios/Intrada/DesignSystem/Theme.swift` | Code is canonical. Colours, type, spacing, radius. Nothing overrides this. |
| **Living design system** | `design/intrada-design-system.dc.html` (+ `support.js`) | Editable reference — open in Claude Design to iterate. Foundations, type language, component catalogue, screen gallery. **Derived from `Theme.swift`.** |
| **Shareable render** | `design/intrada-design-system.html` | Self-contained, offline, no build. For PR review and quick viewing. Regenerated from the `.dc.html`. |
| ~~Pencil frames~~ | ~~`design/intrada.pen`~~ | Deprecated. Keep for history; do not extend. The `light-mode-exploration.md` record stays as provenance. |

The `.dc.html` is the working file; the `.html` is its exported snapshot. Both
trace back to `Theme.swift` — the reference visualises the tokens, it never
defines new ones.

The Claude Design workspace is the claude.ai/design project **"Intrada"**
(`claude.ai/design/p/1b2cc9dd-5805-44a8-9ef5-842cf606f6f9`; the older
`0e60f6f5…` and `cd74e299…` ids 404). It is a plain project, not a design
system, so `DesignSync list_projects` never shows it: reach it by id. **The repo stays
canonical**: Claude Code bridges the two with `DesignSync` — pushing repo
design files up after they change here, and pulling finished mockups down
(design sessions save to project paths like `mockups/`; they cannot write to
GitHub or the repo). Pulled mockups land under `specs/<feature>/design/` per
the SDLC steps below, with `support.js` copied alongside so they render
standalone.

## Committing it

1. Copy into the repo:
   - `design/intrada-design-system.dc.html`
   - `design/support.js`
   - `design/intrada-design-system.html`
2. Open `design/intrada-design-system.html` in any browser to confirm it renders.
3. Update `docs/design-principles.md` if the change alters how the app should
   feel, and append a T-numbered decision there rather than deciding silently.
   Do **not** update `specs/design-system.md`: it documents the deleted Leptos
   web shell (see `specs/README.md`), and this step is a leftover from the
   2026-06 Pencil retirement.

### Regenerating the shareable export

`design/intrada-design-system.html` is Claude Design's "standalone HTML" bundle:
one `<script type="__bundler/template">` holding the whole page as a JSON string,
plus every font, icon and image inlined as an asset (hence about 4.9 MB, well
over DesignSync's 256 KiB `get_file` cap). Two routes:

- **Claude Design's own Share → Export → Standalone HTML**, driven in a browser
  (what #1213 did via Playwright). Needs an interactive claude.ai login, so it is
  unavailable in a headless or non-interactive session.
- **Patch the bundle in place**: decode the template string with
  `json.loads`, apply the same edits made to the `.dc.html`, re-encode with
  `json.dumps(..., ensure_ascii=False)` then `"</" → "<\\u002F"`, and splice it
  back. Verify by decoding again and diffing against the `.dc.html`: the only
  differences should be the bundler's own normalisations (head rewritten with
  inlined fonts, asset URLs replaced by uuids, `viewBox` → `sc-camel-view-box`,
  entities decoded, boolean attributes quoted). Then load the result in a browser
  and check the page height and a new component against the `.dc.html`.

Either way, push the updated `.dc.html` to the project with `DesignSync` first,
so the project and the repo do not drift.

## Adding design to the SDLC

Each feature already moves through `specs/NNN-feature/` (`spec.md` → `plan.md` →
`tasks.md`). Insert a **Design** step between `spec` and `plan`:

1. **Design** — In Claude Design, open `intrada-design-system.dc.html` for context
   and mock the new screens/states using the existing kit. Save the mockup as
   `specs/NNN-feature/design/<screen>.dc.html` (+ exported `.html`).
   - Reuse components and tokens; if something new is needed, that's a signal a
     new primitive/token belongs in `Theme.swift` **and** the design system.
2. **Plan / tasks** — Reference the committed mockup. Build against it.
3. **PR checklist** — add two gates:
   - [ ] If a token or component changed, `Theme.swift` and
         `design/intrada-design-system.dc.html` were updated together.
   - [ ] New screens have a committed Claude Design mockup under their spec folder.

## Keeping code and design in sync

- **New token or component** → change `Theme.swift` first, then update the design
  system reference and re-export the `.html`. Same PR.
- **Exploring a direction** (e.g. the Liquid Glass tab bar) → mock it in Claude
  Design first, get sign-off, then implement in SwiftUI and fold the agreed result
  back into the reference.
- Treat the design system file the way you treat `Theme.swift`: a reviewed,
  versioned part of the codebase — not a throwaway mock.
