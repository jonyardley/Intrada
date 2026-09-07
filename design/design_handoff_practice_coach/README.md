# Handoff: Intrada — The Practice Coach (first wireframes)

> **This is a review request, not a build request.** The primary ask for the
> Claude Code session receiving this bundle is: *does this design align with the
> intended thinking captured in the repo's own documents?* Implementation is a
> later conversation. Section 8 lists the specific questions to answer.

---

## 1. Overview

A first wireframe pass at the **Practice Coach** direction — the pivot described
in `specs/intrada-practice-coach-design.md` (v2, 18 July 2026): an app that
decides what you practise, listens while you play, tells you when you're done,
gets you unstuck, and adjusts the plan from what it hears.

The wireframes walk one complete 20-minute session using the doc's own worked
example (Strasbourg / St. Denis; rootless voicings, A section; the Rollins lick
entering new keys), plus alternates for the two screens the product hinges on.

**Source documents this was built from** (all read in full):

| Document | What was taken from it |
|---|---|
| `specs/intrada-practice-coach-design.md` | The whole structure: product principles, the 10 UX design principles, session template, feedback cadence, stuck ladder, lick pipeline, devices, off-piste, behavioural-research alignment |
| `VISION.md` | Reflection-closes-every-loop, celebrate-comeback-not-streak, designed-for-every-mind, one-tap-to-start |
| `docs/journeys.md` | The ten steps; the companion-loop priority ordering |
| `specs/design-refresh-2026.md` | Read for token/visual history — deliberately **not** applied (see §3) |
| `design/CLAUDE.md`, `design/design-process.md`, `design/HANDOVER.md` | Design-file process, theme decision, the shared-DC import pattern |
| `design/intrada-design-system.dc.html` | Paper & Score palette and type, used for the wireframe ground |

---

## 2. About the design files

The file in this bundle is a **design reference created in HTML** — a wireframe
prototype showing structure, flow, and copy. It is **not production code** and
nothing in it should be copied into the app.

If this direction is approved and later implemented, the target is the native
SwiftUI iOS app (`ios/Intrada/`), using the existing `DesignSystem/Theme.swift`
tokens and component set. The HTML is a thinking artefact only.

The file is a Design Component (`.dc.html`) — open it in a browser directly
(`support.js` sits alongside it and is required). It uses a pan/zoom canvas:
the three options are laid out side by side.

---

## 3. Fidelity — **low-fidelity, deliberately**

These are **wireframes**, chosen over hi-fi at the user's explicit direction:
get the flow right first, then style. Specifically:

- Structure, hierarchy, and **copy** are the deliverable. Read the copy closely —
  it is doing most of the design work, and it is where the doc's tone principles
  ("plain language, musician's language", "never bluff", "honest about the
  grind") either hold or don't.
- Colour is intentionally near-absent: paper (`#FBFAF3` / `#EFEBE0`), ink
  (`#2B2A26`), and a single warm annotation colour. This is the **Paper & Score**
  ground from the existing design system, but no accent bars, no gradients, no
  final type scale.
- Boxes with a **dashed** border are placeholders (notation, waveform, graph
  view). Solid-bordered boxes are real intended surfaces.
- Handwriting-font captions **below** each frame are my annotations to you, not
  UI. Handwriting captions **inside** a frame (warm brown) are design notes about
  the principle that frame is testing.
- The `design-refresh-2026.md` visual language (neutral-dark background, 4px
  gradient AccentRow, Inter/Source Serif) was **not** applied — that refresh
  predates the Practice Coach pivot and is dark-mode-only, whereas
  `design/CLAUDE.md` records light Paper & Score as the MVP default. Flag if
  that's the wrong call.

---

## 4. What's in the file

One turn (`t1`), three options. Every option has a stable id shown as a badge.

### Option `1a` — the full run (13 frames, left to right)

| # | Frame | Purpose | Principle being tested |
|---|---|---|---|
| 1 | **Home** | Tonight's session; one decision | "Kill the choice"; one screen, one action; the why is one line |
| 2 | **Why panel** | Per-block reasoning, citing node state | "The why is always one tap away"; prescription trust (challenge 5) |
| 3 | **Warm-up (block 1)** | Comfortable opener, scored silently | Anti-abandonment; endowed progress; guidance hypothesis |
| 4 | **Active drill (block 2)** | Gate progress, per-rep marks, one fact | Glanceable over readable; honest about the grind |
| 5 | **Stuck ladder** | Escalation after 3 fails | "Make it smaller before they give up"; name the wall |
| 6 | **Block boundary** | The coaching voice, trend, horizon | Praise the tactic not the talent; self-trend horizons (decision 4) |
| 7 | **Lick pipeline** | Phrase stages + key traversal | "All 12 keys is never a session goal"; one phrase in flight |
| 8 | **Analyse → extract** | Why the phrase works; device captured | Theory just-in-time, never a curriculum |
| 9 | **Device inventory** | The growing vocabulary | "The device is the vocabulary; the lick was its carrier" |
| 10 | **Measured vs felt** | What the app heard / what only you can hear | "Never bluff, visibly"; measure prerequisites, coach judgement |
| 11 | **Session close** | Banked, in your own words, tomorrow drafted | Peak-end rule; Zeigarnik; implementation intentions |
| 12 | **Off piste** | Wander logged, "keep as a drill?" | Autonomy (SDT); the graph revealing a gap |
| 13 | **Bad day** | The lighter ten minutes | "Design for the bad day"; lighter, not heavier |

### Option `1b` — Home, three treatments

- **The button** — a start circle and nothing else. Maximum kill-the-choice; no
  trust cue, no bad-day affordance.
- **The plan** — the four blocks listed with times and reasons. Transparent, but
  a list invites deciding, which is the failure mode the doc names.
- **The sentence** — one plain-language claim ("Tonight we fix the A-section
  voicings, then put the new lick into two more keys"), then start. Closest to a
  teacher speaking. **My recommendation.**

### Option `1c` — Active drill, three feedback treatments

- **Numbers forward** — accuracy %, timing ms, swing ratio, drift. Everything
  measurable on screen. Fails the one-second glance test; included as the
  strawman.
- **Gate forward** — one mark, one fact, one count, huge type. Readable at
  arm's length. **Used in `1a`.**
- **Bar map** — an 8-bar strip with the failing bar lit. Diagnostically the
  strongest (it answers *where*), but it asks for a real look — proposed for
  block boundaries rather than mid-rep.

---

## 5. Design decisions I made (and want checked)

The user answered "decide for me" on several questions. These are my calls, all
of them overrulable:

1. **Relationship to the existing app.** Coach-first: the home screen *is* the
   start button. The existing Library / Practice / Routines / Progress tabs are
   demoted to a small header affordance ("library"), not a tab bar. This follows
   "the home screen is a start button" but conflicts with the shipped four-pillar
   IA and with `docs/journeys.md` steps 1–3, which assume the library is a
   first-class surface. **Needs a ruling.**
2. **MIDI visibility.** Quiet — a small `midi ✓` chip in the header, never a
   headline. Backed up by one explicit low-confidence state (frame 10, "probably")
   rather than a connection-status UI.
3. **An extra screen.** Frame 10 (measured vs felt) is not one of the surfaces
   asked for. I added it because "never bluff, visibly" and challenge 2
   (pedagogical authority) had nowhere else to live, and it is where the honest
   scope of the claim becomes visible to the user.
4. **Grind labelling made literal.** Frame 4 carries a `grind · 3 weeks` chip —
   the label, the payoff and the horizon on the drill itself, per principle 4.
   This is the riskiest copy decision in the set; it could read as deflating.
5. **No streak anywhere.** Not on home, not at close. "Banked" and "counts
   towards tonight either way" carry the consistency framing instead.
6. **The close quotes the user's own words** ("bridge still rushing") against
   tonight's data — pulling `docs/journeys.md` step 9 (narrative progress) into
   the coach loop rather than leaving it on a separate Progress tab.
7. **No numbers invented from population data.** The one horizon shown reads
   "your trend suggests roughly four more sessions", per decision 4.

---

## 6. Deliberate omissions

Things in the doc that are **not** drawn, so you can tell whether their absence
is a gap or correct scoping:

- Placement / cold start (parked behind the personal-tool-first decision).
- Count-in, restart detection, attempt segmentation UI — the Phase 1 spike
  outcome should shape this, not a wireframe.
- Listening blocks (no-instrument items) — mentioned in the why panel only.
- Tune pipeline stages (form / melody / shells / rootless / arpeggiate / guide
  tones) as a browsable surface; only the lick pipeline is drawn.
- The graduation arc (principle 8) — no depiction of the UI becoming less
  prescriptive as mastery climbs. **Probably the biggest hole.**
- Goals as an input to planning (`VISION.md`, journeys step 4).
- Any settings, onboarding, or MIDI setup UX (challenge 10).

---

## 7. Design tokens used

Wireframe-level only — not a proposed palette. Lifted from
`design/intrada-design-system.dc.html` (Paper & Score, light).

| Token | Value | Use |
|---|---|---|
| Canvas | `#EFEBE0` | Page ground |
| Paper | `#FBFAF3` | Device surface, cards |
| Ink | `#2B2A26` | Text, borders, filled states |
| Ink muted | `#5C5646` | Body copy |
| Ink faint | `#9A927F` | Labels, secondary |
| Rule | `#C4BCA6` (solid) / dashed | Borders, placeholder outlines |
| Track | `#E2DCCB` | Unfilled progress |
| Annotation | `#8A6A1F` | In-frame design notes only |
| Accent | `#4C3FA6` | Links and the active option badge only |
| Display type | Source Serif 4, 18–52px, weight 400 | Headings, big numerals |
| UI type | Inter, 8.5–19px, weights 400/500/600 | Everything else |
| Annotation type | Caveat, 13–15px | Captions (not UI) |
| Frame | 300×600 (`1a`), 262×500 (`1b`/`1c`), 2px ink border, 20px radius | Phone stand-in |

Minimum in-frame UI text is 8.5px only for uppercase tracked labels; body copy
is 10.5px+ at wireframe scale. **These are not real iOS sizes** — do not read a
type scale out of this file.

---

## 8. Questions for the review session

Answer these against the repo's own documents, not against taste:

1. **Does the session shape match the doc?** Frames 3/4/7/10 map to the 0–3 /
   3–9 / 9–14 / 14–19 blocks and 11 to the 19–20 close. Are the gates as
   specified ("3 clean passes at 120", "2 clean in both keys")?
2. **Principle audit.** Walk the 10 UX design principles in
   `intrada-practice-coach-design.md` and name any that no frame serves — and
   any frame that violates one. Principle 8 (graduation arc) is the one I know
   is missing.
3. **Is the coach-first IA right?** See §5.1. Does killing the tab bar break
   `docs/journeys.md` steps 1–3, or is the library correctly a background
   surface now?
4. **Copy tone.** Read every string. Does any of it slip into gamification
   vocabulary, cheerleading, ability praise, or guilt? Frame 5 ("Three in a row.
   Let's make it smaller.") and frame 4's grind chip are the ones I'd challenge
   first.
5. **Honesty of the numbers.** Anything on screen that implies population data,
   false precision, or a confidence the deterministic MIDI analysis in
   `intrada-core` couldn't actually produce?
6. **Data model fit.** Frames 7, 8 and 9 assume `Phrase` (stage + per-key
   mastery), `Device` (referenced by many phrases, own mastery via the generate
   ladder) and `MethodPack` cues. Does the sketch in the doc's technical
   architecture section support what's drawn, and what's missing?
7. **Phase alignment.** Which frames are Phase 1 (listening gate), which Phase 2
   (prescribed session), which Phase 3 (the voice), which Phase 4? Frame 6 is
   pure Phase 3 — is showing it this early misleading about what v1 is?
8. **Theme call.** §3 — Paper & Score light over the 2026 dark refresh. Right?
9. **What would you cut?** The doc's own content-burden warning (challenge 3)
   says v1 is 5 nodes, 2 method packs, 1 phrase. Do 13 frames overstate v1?

---

## 9. Files in this bundle

- `Practice Coach Wireframes.dc.html` — the wireframes. Open in a browser.
- `support.js` — required runtime for the `.dc.html` file. Not design content.
- `README.md` — this file.

No image assets are used. Screenshots are not included; ask if you'd like them.
