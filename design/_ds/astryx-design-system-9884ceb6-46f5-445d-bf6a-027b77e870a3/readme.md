# Astryx Design System

A design-agent-ready recreation of **Astryx** — Meta's open-source design
system "built for how we build now: by people and the agents working alongside
them." This project packages Astryx's visual foundations (the flagship
**neutral** theme), reusable UI components, foundation specimens, and full-screen
UI kits so agents can generate on-brand Astryx interfaces and assets.

> **Beta / recreation notice.** This is a faithful recreation built from the
> public Astryx source, not the published npm packages. Values (tokens, scales,
> component APIs) are lifted directly from the repo. For production work, install
> the real packages (`@astryxdesign/core` + a theme) — see Sources below.

---

## Sources

Everything here was derived from the official Astryx repository. Explore these
to build richer, more accurate Astryx designs:

- **GitHub:** https://github.com/facebook/astryx — the monorepo. Tokens live in
  `packages/core/src/theme/tokens.stylex.ts`; the neutral theme in
  `packages/themes/neutral/src/neutralTheme.ts`; components in
  `packages/core/src/<Name>/` (each with a `<Name>.doc.mjs` API doc).
- **Docs:** https://astryx.atmeta.com
- **Storybook:** https://facebook.github.io/astryx/storybook/
- **Sandbox:** https://facebook.github.io/astryx/sandbox/
- **npm:** `@astryxdesign/core`, `@astryxdesign/cli`, `@astryxdesign/theme-*`

Assets copied into `assets/` come from the repo (`apps/docsite/public`,
`apps/sandbox/public`). The **CDN / no-build** path exposes every real component
on `window.Astryx` — see the core README's "No build step (CDN)" section for the
complete 150+ component library beyond the subset recreated here.

---

## What Astryx is

Astryx grew inside Meta over eight years to become its most-used design system,
powering 13,000+ apps. It ships **150+ accessible React components**, brand-level
theming, dark mode, ready-to-ship page templates, and a CLI — as one cohesive
system built on **React + StyleX**. Consumers import pre-built CSS and typed
React components (no build plugin, no styling library to adopt). Seven official
themes ship out of the box: **neutral, butter, chocolate, matcha, stone, gothic,
y2k**. This project recreates the **neutral** theme — the muted, minimal
default used throughout the docs (Figtree type, Lucide icons, a grayscale spine
with an OKLCH-derived categorical palette).

**Products / surfaces represented here:**
- **Component library** — the core primitives (`packages/core`).
- **Application UI** — dense product screens (dashboards, settings, tables)
  that Astryx is built for; see `ui_kits/console`.
- **Marketing / docs** — the Astryx site's own brand voice; see `ui_kits/site`.

---

## Content fundamentals

How Astryx writes, lifted from its component docs, READMEs, and site copy.

- **Voice: plain, confident, second-person.** Docs address the reader as *you*
  and describe what a component does in one crisp sentence: *"Button triggers an
  action when clicked."* *"Badge highlights a status or category at a glance."*
- **Guidance over rules.** The system's stated principle is *"Guidance over
  enforcement… if you pass a value, the component renders it."* Copy teaches
  trade-offs rather than dictating.
- **Do / Don't framing.** Best-practice guidance is written as paired
  affirmative/negative statements: *"Reserve primary for the single most
  important action"* vs *"Place more than one primary button in the same view."*
- **Labels describe the action.** UI copy guidance: *"Save changes", "Delete
  account", "Send invite"* — never *"OK"* or *"Click here."*
- **Sentence case everywhere.** Buttons, labels, headings, menu items all use
  sentence case ("Save changes", not "Save Changes"). Small overline labels
  (heading-5/6) are the only uppercase moments.
- **Concise and scannable.** Banner titles are short: *"Payment failed"*, not
  *"There was a problem processing your most recent payment."*
- **No emoji, no exclamation.** The tone is calm and professional; emphasis
  comes from hierarchy and color, not punctuation or emoji.
- **AI + people, one system.** Marketing copy leans on the dual audience:
  *"built for how we build now — by people and the agents working alongside
  them."* Confident, technical, never breathless.

---

## Visual foundations

The look of the neutral theme, and the rules that produce it.

- **Color — a grayscale spine + categorical accents.** The UI is built almost
  entirely from a pure neutral ramp (`#fafafa → #0a0a0a`). The theme *accent* is
  near-black (`#262626`) in light mode / near-white in dark — colored UI is the
  exception, not the rule. A from-scratch **OKLCH categorical palette** (red,
  orange, yellow, green, teal, cyan, blue, purple, pink, gray) supplies category
  tags and status. Each hue splits into four tonal stops: `background` (subtle
  surface), `border` (ring), `icon`, `text` (vivid). **Max 1–2 accent colors per
  screen.**
- **Status vs categorical.** Semantic status (success/warning/error/info) uses
  **solid saturated fills** to demand attention. Categorical hues use **tinted
  pastel surfaces + colored text** for quiet classification. Light mode = pastel
  bg + dark text; dark mode inverts to a hue-tinted overlay + light pastel text.
- **Typography — Figtree, 14/1.2 scale.** Body and headings are **Figtree**
  (loaded from Google Fonts); code is the system monospace stack. The type scale
  is geometric: base **14px**, ratio **1.2**. Headings are semibold (600), with
  **h3/h4 bumped to bold (700)** for subsection punch. Display sizes (29–42px)
  continue the ratio at normal weight with tighter leading (~1.24).
- **Spacing — 4px base.** A named scale `spacing-0 … spacing-12` (0, 2, 4, 6, 8,
  12, 16 … 48px). Layout leans on flex/grid + `gap`; cards and sections pad at
  `spacing-3` (12px).
- **Radius — soft, not pill.** `inner 6 · element 10 · container 12 · page 28 ·
  full`. Buttons/inputs use `element` (10px); cards use `container` (12px);
  chat + page surfaces use `page` (28px).
- **Elevation — shadows do the lifting.** Three ascending drops (`low/med/high`).
  In light mode surfaces are white/tinted and shadows are subtle; in dark mode,
  cards share the body tone and lift via **deeper drops + a 1px white inset
  "bezel"** on every edge. Cards = `shadow-low`; popovers = `shadow-med`;
  modals/toasts = `shadow-high`.
- **Backgrounds — flat, Figma-style.** No gradients, no photographic hero
  washes, no textures. A single lifted `surface` tone floats above a slightly
  tinted `body`. Brand moments use flat **Astryx blue `#225BFF`**.
- **Borders.** Hairline `--color-border` (near-invisible) for structure;
  `--color-border-emphasized` for input outlines and defined channels
  (switch/progress tracks).
- **Motion — snappy.** One easing (`cubic-bezier(0.24, 1, 0.4, 1)`) and a fast
  scale: micro-interactions **125ms**, entrances **300ms**. Reduced-motion is
  honored (durations collapse to 0s). No bounces; transitions are quick fades +
  a subtle **0.98 press-scale** on buttons.
- **Interaction states.** Hover = a translucent overlay tint layered over the
  base (`overlay-hover`), never a hardcoded new color. Press = a darker overlay
  (`overlay-pressed`) + scale-down. Focus = a **2px accent outline at 3px
  offset** (error components focus in error red). Disabled = `opacity: 0.5`.
- **Inputs.** Surface background, `border-emphasized` outline, `element` radius;
  focus swaps to a blue border + a 2px inset ring. Validation shows a colored
  border, a status icon, and a message below.
- **Transparency & blur.** Used sparingly — overlay scrims for modals, alpha
  overlays for hover/press tints and dark-mode categorical surfaces. No heavy
  glassmorphism.
- **Corners, cards, and chips.** Cards: 1px hairline border + `container` radius
  + `shadow-low` + surface background. Badges/pills: `full` radius. No
  colored-left-border callouts, no rounded-corner-with-accent-stripe tropes.

---

## Iconography

- **Icon set: [Lucide](https://lucide.dev).** The neutral theme registers Lucide
  icons for all semantic slots (close, chevrons, check, status, search, calendar,
  etc.). Stroke-based, ~1.5–2px weight, rounded caps and joins.
- **Sizing.** Icons render at `1em` and inherit `currentColor`; button/input
  icons are 16px (20px at `lg`). They are `aria-hidden` by default — the
  component's label carries the accessible name.
- **How to use.** Components take icons as `ReactNode` props (`icon`,
  `startIcon`, `endContent`). In HTML mocks, load Lucide from CDN
  (`https://unpkg.com/lucide` → `lucide.createIcons()`), as the Brand ›
  Iconography specimen and the UI kits do. **Do not hand-draw icons** — use
  Lucide (or, in code, `lucide-react`).
- **No emoji, no unicode glyphs** as icons anywhere in the system.
- Brand marks live in `assets/`: `brand-icon.svg` (the blue pinwheel),
  `logo.svg` (the `⟮XDS⟯` wordmark), `feature-brand.png`, `avatar.png`.

---

## Components

Reusable primitives recreated from `packages/core`, grouped by concern. Each has
a `.jsx` implementation, a `.d.ts` props contract, and a `.prompt.md` usage note.
Consumed via `const { Name } = window.AstryxDesignSystem_9884ce`.

**Core** (`components/core/`) — `Button`, `IconButton`, `Badge`, `Card`
**Forms** (`components/forms/`) — `TextInput`, `TextArea`, `Select`, `Switch`, `Checkbox`, `RadioGroup`, `SegmentedControl`
**Feedback** (`components/feedback/`) — `Banner`, `Toast`, `Spinner`, `Skeleton`, `StatusDot`, `ProgressBar`
**Navigation** (`components/navigation/`) — `Tabs`, `Breadcrumbs`
**Data** (`components/data/`) — `Avatar`, `Divider`

> **Scope.** The real Astryx core ships **150+** components. This project
> recreates the ~21 most-used primitives spanning every category as a faithful,
> brand-accurate starting set. For the full library (Table, Chat, CommandPalette,
> DropdownMenu, TopNav/SideNav, DateInput, Tooltip, Popover, Carousel, …) use the
> real `@astryxdesign/core` package or the `window.Astryx` UMD CDN build.
>
> **Intentional additions:** none — every component maps to an Astryx core
> component. `RadioGroup` consolidates Astryx's `RadioList`; `Tabs` maps to
> `TabList`.

---

## UI kits

Full-screen, click-through recreations composed from the components above:

- **`ui_kits/console/`** — an internal-tool product surface (the kind Astryx is
  built for): app shell with side nav + top bar, a data dashboard, and a
  settings screen. `index.html` is the interactive entry.
- **`ui_kits/site/`** — the Astryx marketing/docs voice: a hero, feature grid,
  and component-doc page layout.

---

## Index / manifest

Root files and where to look:

- `styles.css` — **the single entry point consumers link.** `@import`s the whole
  token + font closure below.
- `tokens/` — `fonts.css`, `colors.css`, `typography.css`, `spacing.css`,
  `radius.css`, `shadows.css`, `motion.css`, `base.css`.
- `components/<group>/` — the reusable primitives (see Components).
- `guidelines/` — foundation specimen cards (Colors, Type, Spacing, Brand),
  shown on the Design System tab.
- `ui_kits/<product>/` — full-screen product recreations.
- `assets/` — logos, brand icon, imagery, avatar.
- `thumbnail.html` — the design system's homepage tile.
- `SKILL.md` — makes this system usable as a downloadable Agent Skill.

Tokens: 190 · Components: 21 · Foundation specimens: 14 · UI kits: 2.
