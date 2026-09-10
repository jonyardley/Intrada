# Onboarding welcome (first-run intro cards)

> **⚠️ Historical record.** Parked by the 2026-07 coach pivot, which was
> reversed on 2026-08-13 (#1344). The web shell this spec targeted stayed
> deleted, so the surface did not return with the restored session builder.
> The first-run thinking is largely direction-agnostic; a native welcome would
> start from here rather than implement this as written.

> Spec for the first-time-user welcome experience.
> Tier 3 per CLAUDE.md (brand-defining first impression — earns a written
> spec even though the implementation surface is web-shell-only).

## Problem

A user who signs into intrada for the first time today lands directly on
the empty Library list (`app.rs`, in the now-deleted web shell).
There is no welcome, no philosophy, no setting of expectations — they sign
in with Google and are dropped into an empty screen with a `+` button.

This is a missed moment. intrada is not a generic music-practice tool — it
is a specific response to specific frustrations (the "comfort trap",
unstructured practice, the friction of knowing where to start). The first
60 seconds is when a new user decides whether the app understands them.
Right now, the app says nothing at all.

## Goals

1. A new user sees a short, delightful, authentic welcome before reaching
   the empty Library — once per device.
2. The welcome introduces intrada's central insight (the *comfort trap* —
   it's easy to play what you already know; progress lives in the parts
   that take effort) without lecturing or citing research.
3. The welcome speaks in a personal, maker's-note voice — distinct from
   any other practice app — and surfaces the underlying research
   *implicitly* via the worldview the cards convey.
4. The welcome ends with a clear, low-friction handoff to the Library
   ("Get started →"), where the user can choose their own first
   action — adding a piece, exploring a set, or just looking around.
5. A user who has seen the welcome does not see it again on the same
   device. A development affordance allows re-triggering it for design
   work and testing.

## Non-goals

- **Personalisation.** No track-selection, no instrument capture, no
  starter-library suggestion. That work belongs to
  [#100 Personalisation](https://github.com/jonyardley/intrada/issues/100).
- **Server-side persistence.** v1 stores the "seen" flag in localStorage
  only. This is intentional — see *Future work* for the upgrade path.
- **A "Show welcome again" affordance in production.** Out of scope for
  v1. Dev-only re-trigger is sufficient for now.
- **Photographic or illustration-heavy treatment.** The voice is
  typographic and intimate; visual production-load belongs to a future
  pass.
- **iOS-platform-specific welcome content.** Same cards on web and iOS;
  iOS adds the existing platform-feel layer (haptics, view transitions,
  safe-area insets) — no separate copy or layout.

## Approach

### Voice and content arc

Five cards: one maker's-note opener followed by a plain-language
walkthrough of the core loop — Capture → Plan → Practice → Track.

Each loop card has three text layers — a small **pillar label**
(uppercase, muted), a punchy **anchor phrase** (large serif), and a
**continuation** (medium body, muted). The opener (card 1) skips the
label deliberately; breaking from the structure on the first card makes
the structure that follows feel intentional rather than templated.

| # | Pillar label | Anchor phrase | Continuation |
|---|---|---|---|
| 1 | *(none — opener)* | "Knowing how to practise well is hard." | "I've struggled with it. So I built this." |
| 2 | CAPTURE | "Build a library" | "of pieces and exercises — the things you're actually working on." |
| 3 | PLAN | "Practise with intention" | "Plan each session. Decide where the effort goes before you pick up the instrument." |
| 4 | PRACTICE | "Focus, reflect, move on" | "Run timed sessions. Score what happened while it's still fresh, then on to the next." |
| 5 | TRACK | "Watch the work add up" | "Music improves between sessions, not within them — so the data shows what your ears can't hear yet." |

Final-card CTA routes to `/` (the Library home, not `/library/new` —
the welcome should hand off to the empty library, not push the user
into a specific form action). Skip also routes to `/`. Either action
records the "seen" flag.

CTA label: **"Get started →"**.

These lines are the spec — not placeholders. They are derived from a
brainstorming interview and two deliberate content reviews, chosen
because the opener speaks in a voice no other practice app uses, and
the loop cards introduce exactly the concepts a new user will encounter
first. Edits should be deliberate (PR review, not drift).

### Visual treatment

**Layout — vertical stack per card** (top to bottom):

1. **Animated SVG mark** (~80px square)
2. **Pillar label** (small, uppercase, `text-muted`, `field-label`-styled)
3. **Anchor phrase** (large, `font-heading` Source Serif, `text-primary`, `page-title`-sized)
4. **Continuation** (medium body, `text-muted`)

Generous spacing between layers. Background uses the existing dark
gradient already wired in `app.rs`, in the now-deleted web shell.

**Per-card animated SVG mark — built from the brand vocabulary.**
Every card (including card 1, the opener) gets a small mark composed
of the same primitives as the Digital Logo Kit: **horizontal lines +
violet/amber dots**. Each animation expresses the per-card concept
through what the dots do on the lines (settle, snap, align, pulse,
progress). By card 5 the user has seen the same vocabulary five times
in different motions; it registers as a brand rather than five
disparate icons.

Hand-coded inline SVG (no Lottie, no external files); animation runs
via CSS `@keyframes` on `stroke-dasharray` / `stroke-dashoffset`,
`cx`/`transform`, and opacity. The mark stays at its final state once
the animation completes; it does NOT loop. Re-entering a card replays
the animation from start. Total duration ~600–900ms depending on the
mark's complexity (line draw + dot slide is two beats; align is one).

| # | Mark animation |
|---|---|
| 1 | A single line draws in left→right; a violet dot slides along it and settles. The brand mark in motion — frames the whole welcome and links to the maker's "knowing where to put the effort" theme. |
| 2 | Three lines draw in (top→bottom). Amber, violet, amber dots snap onto each line at varied positions — items captured into slots. |
| 3 | Three lines with violet dots scattered at different positions. Dots slide horizontally and align at the same vertical column — *deciding where the effort goes*. |
| 4 | A single line with one violet dot pulsing, with concentric rings emanating (metronome / heartbeat). An amber dot enters from the right and joins. |
| 5 | Three lines with violet dots. Dots slide rightward in a stagger — left, middle, right — reading as progression along tracks. |

**Colours and stroke conventions — pulled from the live code design
system, not the Pencil file.** The Pencil file's Digital Logo Kit is a
visual reference; the source of truth for tokens is
`crates/intrada-web/input.css`.

- Lines: `var(--color-text-faint)`, `stroke-width: 2`,
  `stroke-linecap: round` — matches the existing `Icon` component
  convention in `crates/intrada-web/src/components/icon.rs`.
- Violet dots: `var(--color-accent)` (the primary brand accent in the
  live token system — `oklch(50.5% 0.24 274)` warm indigo, not the
  hex value shown in Pencil).
- Amber dots: `var(--color-warm-accent)` (the live token —
  `oklch(70% 0.12 78)` muted gold, used elsewhere for analytics bar
  charts and tags).
- No new tokens are added for this work.

**Mark size and viewBox.** 80×80 px display size, 80×80 viewBox so
SVG coordinates map 1:1 to display pixels and `stroke-width: 2` reads
visually consistent with the rest of the app's icon set.

**Motion.** Card-to-card transition stays as today: ~200ms opacity +
translate-y on the `welcome-card-content--entering` / `--visible`
classes. The SVG mark animation runs *in addition*, kicked off by a
CSS animation tied to a key per card index (so swiping back-then-forward
to the same card replays the animation, not skips it).

**Reduced motion.** Under `@media (prefers-reduced-motion: reduce)`,
both the card transition and the SVG draw-in animation collapse to
their final state instantly — no fade, no draw, no pulse.

**Tokens only.** No raw Tailwind colour classes. Anchor uses
`page-title`. Label uses `field-label`. Continuation uses `text-muted`
on body text. Spacing uses `p-card-comfortable` and the standard
spacing scale.

### Flow

- Swipe left to advance, swipe right to go back (mobile);
  tap-anywhere-to-advance (desktop); tap any progress dot to jump.
- Five progress dots at bottom, current one filled.
- "Skip" link top-right — small, low-contrast (`text-muted`), present
  but not pushy. Skips to `/` and records the flag.
- Final card's primary CTA is a Hero-size primary `Button` (from the
  now-deleted web shell): *"Get started →"*. Tapping records the flag and
  routes to `/` (the Library home).

**iOS polish** (under `[data-platform="ios"]`):

- `selection` haptic on advance (every card change).
- `light` haptic on the final CTA tap. *(The earlier draft of this spec
  called for `success`. We use the `Button::Primary` primitive which
  already fires `haptic_light` internally; firing a separate `success`
  on top would double-tap on iOS hardware. Keeping the single `light`
  haptic — the navigation to `/` carries the success semantic on its
  own.)*
- `light` haptic on Skip.
- Safe-area insets on top (Skip link) and bottom (progress dots + CTA).

### Persistence

**localStorage flag.** A single `intrada:welcome-seen` key, written when
the user taps Skip or the final CTA.

```ts
localStorage.setItem('intrada:welcome-seen', '1');
```

The carousel is gated on `localStorage.getItem('intrada:welcome-seen')
=== null`. This check happens once at app boot, after Clerk reports a
signed-in state — see *Architecture* below.

**Trade-off accepted:** a user who signs in on a second device (e.g.,
web first, then iPad) sees the welcome again. For a one-time ~30-second
maker's-note experience, this cost is small. If/when other per-user
preferences land (track, instrument, defaults — see #100), this flag
migrates server-side as part of that work.

### Dev re-trigger affordance

Two paths, both `#[cfg(debug_assertions)]`-gated:

1. **Design catalogue entry.** Add `WelcomeCarousel` to
   `views/design_catalogue.rs` (in the now-deleted web shell) so it can be
   inspected in isolation at `/design`. The design route is already
   debug-gated in `app.rs`, in the same shell.
2. **Reset button** in the design catalogue entry that clears
   `localStorage.removeItem('intrada:welcome-seen')` and reloads.

No production "Show welcome again" link. If the need arises later, it
is one line.

### Architecture

This is a **web-shell-only** change. No Crux core changes, no API
changes, no DB migrations.

- **Components** in `crates/intrada-web/src/components/`:
  - `WelcomeCarousel` — the overlay container. Owns card index state,
    swipe/tap handling, progress dots, Skip link, transitions, and the
    localStorage write.
  - `WelcomeCard` — slot for a single card. Takes `label`, `anchor`,
    `continuation`, and a `mark` slot for the per-card animated SVG.
    Used five times by the carousel; card 1 passes `label=None` to
    skip the pillar label.
  - One inline SVG component per card (or one parameterised `WelcomeMark`
    that selects the right path set by index) — kept inside
    `welcome_carousel.rs` rather than its own module since the marks are
    short, only used here, and benefit from being adjacent to the card
    they belong to.
- **Mount point.** Inside `AuthenticatedApp` (`app.rs`, in the now-deleted
  web shell), render `<WelcomeCarousel />` as a *sibling* of `<main>` (not
  wrapping it),
  positioned `fixed inset-0 z-[2000]` so it sits visually above the
  routed content. The app underneath continues to mount and fetch data
  so that the Library at `/` is already loaded when the carousel
  dismisses. Visibility is gated on a `RwSignal<bool>` set once at
  `AuthenticatedApp` mount from the localStorage check.
- **No Crux event surface.** Onboarding state in v1 is shell-local UI
  state, not domain state. This intentionally diverges from CLAUDE.md's
  "domain data lives in Crux" rule because the localStorage flag is
  *not* domain data — it is per-device UI state with no server-of-record
  and no cross-shell sharing requirement. When the flag migrates to
  server-side (#100), it becomes domain state and moves into core.
- **No Tauri plugin.** Haptics use the existing `tauri-plugin-haptics`
  bindings. View Transitions use the existing wasm-bindgen bridge.
- **Pencil first.** The five cards and the carousel chrome (dots, Skip,
  CTA) get screens in `design/intrada.pen` before implementation, per
  CLAUDE.md's Pencil workflow.

## Testing

- **Component test (in design catalogue).** Manual, but the catalogue
  entry exercises every state.
- **E2E (Playwright).** Spec covering:
  - Fresh localStorage → sign-in → welcome shows → tap through 5 cards →
    final CTA → land on `/`.
  - Fresh localStorage → sign-in → welcome shows → tap Skip → land on
    `/`.
  - localStorage primed (default for the shared fixture) → sign-in →
    no welcome.
- **No core unit tests** — there is no core change.
- **No API integration tests** — there is no API change.

## Risks and unknowns

1. **Tone calibration.** The maker's-note voice is the boldest part of
   the design. If it lands as too personal or self-indulgent in usage
   testing, the cards can be rewritten without architectural change —
   but the architectural commitment to "intimate typographic welcome"
   stays.
2. **Flag-couples-to-device.** If the proportion of users who sign in
   on multiple devices is high, the "shows again on iPad" cost is
   higher than estimated. Acceptable for now; revisit if anecdotal
   feedback says otherwise.
3. **Gradient legibility.** The existing dark gradient was designed
   for the routed app (cards on top of it). At full-screen with no
   card surface, contrast on muted text needs a Pencil pass.

## Future work

- **Server-side persistence** as part of [#100 Personalisation](https://github.com/jonyardley/intrada/issues/100).
  Requires `user_preferences` table + `GET/POST /me/preferences` + a
  new core slice. Migration path: backfill `onboarded_at = now()` for
  any user whose localStorage already had `welcome-seen`.
- **Production "Show welcome again" affordance** (settings or About
  screen). One line once server-side persistence lands.
- **Track-shaped welcome.** Once Musician Tracks (#193) ship, an extra
  card (inserted before card 5, or replacing card 1) can offer a
  light track self-identification. Out of scope for v1 by explicit
  decision earlier in design.
- **Returning users re-onboarding.** A "what's new" treatment is
  conceptually the same component. Different flag, different content.

## References

- [VISION.md](../VISION.md) — five layers, three pillars, core
  principles.
- [docs/research-foundation.md](../docs/research-foundation.md) §3
  Deliberate Practice, §9 Choice Overload — the research the
  "comfort trap" insight rests on.
- [#100 Personalisation epic](https://github.com/jonyardley/intrada/issues/100)
  — where server-side persistence ultimately belongs.
- [#193 Musician tracks](https://github.com/jonyardley/intrada/issues/193)
  — the closed exploration that informs *Future work*.
- [specs/background-audio-plugin.md](background-audio-plugin.md) — Tier-3
  spec template followed here.
