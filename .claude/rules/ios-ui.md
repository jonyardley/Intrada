---
paths:
  - "ios/Intrada/**/*.swift"
---

# Paper & Score: the design system rules

Off-white paper, brown ink, one highlighter as the only bright colour, butter
by default and the musician's own choice through `@Environment(\.marker)`
(#1677); Hanken Grotesk for titles and body, DM Mono for metadata (T24 in
`docs/design-principles.md`). Every token lives in
`ios/Intrada/DesignSystem/Theme.swift`; the shareable export is
`design/intrada-design-system.dc.html`, derived from it (behind the app until
#1678).

How the app should feel, and the dated T-numbered decisions log, is
`docs/design-principles.md`: read it before a new surface, layout, flow or
interaction, and append a decision there rather than settling a tension
silently. Every user-facing string is written against `docs/tone-of-voice.md`
and its V-numbered log; its sweep checklist is the review pass for any PR that
changes a string. Where the two disagree, the design principle wins and the
tone doc gets a new example.

## Tokens, then modifiers, then components, then screens

1. Every colour, font, spacing and radius value traces to `IntradaColor`,
   `IntradaFont`, `IntradaSpacing` or `IntradaRadius`. Never a raw hex,
   `.padding(16)` or `cornerRadius: 12`. Genuine one-offs (a fixed component
   height, a 2pt baseline nudge) stay literal.
2. Reuse before creating: check `ios/Intrada/DesignSystem/` and
   `ios/Intrada/Views/Components/` first. Primitives to reach for: `TagChip`,
   `TypeBadge`, `ScoreRing`, `BottomSheet`, `SegmentedPills`, `CardSurface`,
   `CardShadow`, `GlobalBanner`, `FormErrorBanner`, `PlaceholderContent`,
   `ScreenScaffold`, `SectionHeader`, `HairlineDivider`, `SegmentedProgress`,
   `Eyebrow`.
3. Every top-level screen is built from `ScreenScaffold`, which owns chrome,
   safe areas and background.
4. If a primitive almost fits, add a parameter to it (as `SegmentedPills` and
   `LibraryItemCard` do). Never ship a parallel one-off: hand-rolled copies of
   an existing primitive are the number one source of visual drift.
5. Typography through `IntradaFont` (`.pageTitle`, `.cardTitle`,
   `.sectionTitle`, `.fieldLabel`), spacing through `IntradaSpacing`
   (`controlGap`, `cardCompact`, `row`, `card`), motion through `Motion.swift`.

Deviation is allowed only in an explicit redesign, which is a flagged
conversation (Claude Design first, then plan mode) and produces updated tokens
and primitives in `Theme.swift`, not a clone in one view.

## Animated reveals need an opaque backing

Anything that slides or fades over other content (a search bar, an expanding
row, a banner) paints an opaque token (`paperTop` or `cardFill`, never
`clear`), or the transition ghosts. The moving view hides what it travels over;
chrome it emerges from behind must also be opaque and sit on top (`.zIndex(1)`).

## Native feel

- Haptics through the `Store+Feedback` helpers: `selection` for tabs, `light`
  for taps, `success` for saves only after the core confirms, `warning` for
  destructive confirms.
- iPad list-to-detail screens use `LibrarySplitView`, built with the view.
- Respect safe areas; `ScreenScaffold` handles them.

Design happens in Claude Design (`docs/design-workflow.md`). Mock against the
existing kit first; if something new is needed, update `Theme.swift` and the
design reference (with its `support.js`) together, and re-export the shareable
`design/intrada-design-system.html`. Pencil (`design/intrada.pen`) is retired.
