# intrada — Product Roadmap

*This is a vision and prioritisation doc, not a project plan. For what's
actually shipping right now, run `just status` (one screen, read from GitHub),
or see the [project board](https://github.com/users/jonyardley/projects/2)
and [open issues](https://github.com/jonyardley/intrada/issues).*

---

> ## ⚠️ THE 2026-07 COACH PIVOT WAS REVERSED (2026-08-13)
>
> Between July and August 2026 the product direction was the **practice
> coach**: the app decided what you practised, gated every block on evidence,
> and told you when you were done. It was built through Phase 2b and then
> **removed on 2026-08-13** (#1344): the direction went too far too fast, and
> the call was to restore the session-builder product. The coach code is
> recoverable from commit 071b85b; the design record stays in
> [`specs/intrada-practice-coach-design.md`](../specs/intrada-practice-coach-design.md)
> and [`specs/intrada-coach-engine.md`](../specs/intrada-coach-engine.md)
> (both bannered), the assessment that drove the pivot in
> [`docs/rebuild-review.md`](rebuild-review.md), and the machine-listening
> spike findings in [`segmentation-findings.md`](segmentation-findings.md).
>
> What the product does today is the restored builder flow: build a session
> from the library, group and reorder, play it through the Focus Player,
> reflect on the summary. The near-term direction is the audit backlog in
> [`audit-2026-08.md`](audit-2026-08.md) (refine the builder, step by step);
> **the next major direction stays open** and is Stage 4 of
> [`rethink-plan.md`](rethink-plan.md). The post-revert triage (2026-08-14)
> closed the defunct coach-era issues and unparked the builder-era ones; the
> `superseded-by-pivot` label is empty and retired.

---

## How to read this doc

intrada serves the five layers of the [Product Vision](../VISION.md):
**Capture → Plan → Space → Show → Guide**. The layers build on each other
— you can't schedule what you haven't captured, can't space what you
haven't scheduled, can't show progress on what you haven't tracked.

The roadmap is also organised around three activity pillars — **Plan**
(decide what to practise), **Practice** (play with intention), and
**Track** (see the process working) — that cut across the layers.

This doc names the layers, pillars, and prioritisation principle.
**Issues on the [project board](https://github.com/users/jonyardley/projects/2)
are the source of truth for scope and timing.** When this doc and the
issues disagree, the issues are right.

---

## Where the product is today

Capture, Plan, Space (manual), and Show (analytics) all have working
surfaces. Auth, library, sessions, routines, scoring, focus mode, tempo
tracking, design system, multi-device shell, E2E tests — all done. The
native SwiftUI iOS app (on the Crux core — see
[`specs/native-ios.md`](../specs/native-ios.md)) is the only shell; the
Leptos web app and the Tauri iOS host were **deleted** in #1133, not paused.

The active gaps are deeper Layer-1 capture (multi-key, sections, archive),
the rest of the Space layer (per-item scheduling state and resurfacing; its
first slice, the getting-cold signal, landed in #1416), and parts of Show
(timeline charts, calendar). Layer 5 (Guide / AI) is intentionally on the
horizon.

Filter `is:open is:issue` on the board to see what's currently in flight.

### Current focus

The coach pivot is reversed (see the banner at the top). Phase R
([`rethink-plan.md`](rethink-plan.md)) ran the audit backlog in
[`audit-2026-08.md`](audit-2026-08.md) and chose the next direction, pushing
the capture line, whose first slice shipped in 2026-09. Which release is out
and what phase we are in lives in [`where-we-are.md`](where-we-are.md), the one
place that says it; `just status` and the
[project board](https://github.com/users/jonyardley/projects/2)
say what is in flight.

---

## Three pillars

### Plan — "Decide what to practise"

Before the instrument comes out. Building sessions, organising the
library, and eventually letting the app decide for you. Spans Layers 1
(Capture), 2 (Plan), and 3 (Space).

→ [`pillar:plan`](https://github.com/jonyardley/intrada/labels/pillar%3Aplan)

### Practice — "Play with intention"

Instrument is out. Timer running. The app stays out of the way and
supports focus, not admin. Lives mainly in Layer 4 (Show — encouragement,
feedback) with cross-cutting accessibility concerns.

→ [`pillar:practice`](https://github.com/jonyardley/intrada/labels/pillar%3Apractice)

### Track — "See the process working"

After the session. Analytics, insights, visualisation. Evidence the
practice is actually working. Mostly Layer 4 (Show); Layer 5 (Guide) when
AI work becomes timely.

→ [`pillar:track`](https://github.com/jonyardley/intrada/labels/pillar%3Atrack)

---

## Prioritisation principle

**Vision layer first, then pillar.** Layer 1 features take precedence
over Layer 2, which take precedence over Layer 3, and so on. Within a
layer, the three pillars advance independently.

The question is *"what's the most important thing I haven't captured
yet?"* before *"what's the smartest way to schedule it?"*

### Now / Next / Later in your head

- **Now** — a real musician hits a wall *because* this isn't built.
- **Next** — a real musician notices it's missing after a month of use.
- **Later** — the app could live without it for a year.

These are tags on issues, not buckets in this doc. They drift as work
ships and as we learn.

---

## Mobile shell — settled

The native SwiftUI app on the shared Crux core **is** the shell, and has been
since the 2026-05-31 decision completed: app-first, **local-first** (on-device
SQLite is the source of truth; Axum + Turso is a future sync target, not the live
read path). The Tauri 2 + Leptos WKWebView host and the Leptos web app were
deleted in #1133; two pieces of Swift worth reusing were mined into
`ios/Reference/` first — the background-audio session handling and a Live
Activity implementation.

See [`specs/native-ios.md`](../specs/native-ios.md) for the shell spec. Work
tracks under [`ios`](https://github.com/jonyardley/intrada/labels/ios).

Historical note: the sentences that used to live here ("the web app stays on
Leptos, untouched", "the Tauri shell stays shipping until parity") were true in
May and false by July. Statements about what is *currently* shipping belong in
one place — the banner at the top of this doc.

---

## Delivery model

### Labels

| Label | Purpose |
|-------|---------|
| `pillar:plan` / `pillar:practice` / `pillar:track` | Activity pillar |
| `layer:capture` / `:plan` / `:space` / `:show` / `:guide` | Vision layer |
| `horizon:now` / `:next` / `:later` | Rough timing — 4 wk / 4–12 wk / 12+ wk |
| `architecture` | Technical debt, infrastructure |
| `ux` / `accessibility` | Cross-cutting |
| `security` | Security-relevant |
| `ios` | iOS-specific (native SwiftUI shell) |
| `epic` | Umbrella issue with sub-items |

### Board

[Project board](https://github.com/users/jonyardley/projects/2) columns
are workflow states (Backlog → Ready → In Progress → In Review → Done),
not categories. Use the labels above to filter and slice.

**Ready is the pull queue, not the release.** An issue earns Ready when
someone could start it without asking a question first: the shape is
settled and what it points at has been read. It says nothing about which
build it lands in.

**The milestone is the release.** Everything meant for the next cut carries
that release's milestone, which the board already holds as a field and
filters on. Keeping the two apart is the point: an issue can be ready to
start and deliberately out of the cut, or in the cut and not yet
understood, and neither has to lie about the other.

A `Priority` custom field (P0/P1/P2) ranks within a pillar/layer when
multiple items share the same horizon.

---

## Open questions

These are unresolved product questions. Each one likely produces issues
(or a Tier-3 spec) once answered.

1. **Metronome (answered 2026-08-14).** The builder product does want one:
   tracked as #1366 (audit Phase 4), with tempo as a tracked unit of
   measure. The coach-era click (removed in #1344, recoverable from
   history) and the preserved `ios/Reference/` audio-session Swift are the
   starting points.

2. **Offline-first architecture (resolved 2026-07).** The native app is
   offline-first by design — on-device SQLite is the source of truth, with
   test-enforced invariants (see CLAUDE.md). #41 closed. What remains is the
   future paid sync tier, deliberately deferred.

3. **Scoring + tempo coupling (answered 2026-08-27).** The question as
   written (must every mark carry a tempo, or is tempo optional for items
   with targets?) was overtaken by the code: tempo capture shipped inside
   the metronome work (#1398, #1401) and made the stepper appear on every
   item, always saving, pre-filled from the click's tempo even when the
   click never sounded. So every mark already carries a tempo and many of
   those numbers are an untouched default.

   **A tempo is recorded when there is evidence behind it, and never
   otherwise** (Jon): either the user moved the stepper, or the click was
   sounding, so the number measures what they actually played to. Tempo is
   neither required nor optional-by-target; it is recorded when it was
   measured. This matters for the tempo trend (#1420), which draws the
   history as a chart, and a chart looks like measurement.

   Costs no new field: `UpdateEntryTempo` already carries `Option<u16>` and
   `SetlistEntry.achieved_tempo` already skips `None`. Keep it that way, because
   `SetlistEntry` sits inside the `ActiveSession` crash-recovery blob. The
   ViewModel projection is the opposite: `tempo_trend` deliberately carries a
   slot for every practised session, so the chart can break its line where
   nothing was measured.

   **Implemented 2026-08-28** (#1420, the first of its three PRs) as design-principles
   **T16**. One correction to the framing above: the untouched pre-fill is not
   always the neutral 96. `ClickController` seeds from the item's own declared
   target, so for an item marked ♩ = 132 the app was recording 132 as achieved. The shell forwards two observed facts (`TempoObservation`) and the
   core rules on them; no new field, no crash-recovery key bump. Pre-fix
   history on device is accepted rather than migrated away: there was
   essentially none, so nulling it would have been destructive work with
   nothing to show for it.

4. **Teacher integration timing.** Currently a Layer-5 horizon. Basic
   sharing (routines, item suggestions) could come earlier without AI.
   The teacher-assignment capture (#267) addressed the immediate capture
   problem without teacher-facing features.

5. **Goals (re-resolved 2026-07-14).** History: goals were built twice
   (an early goals feature, removed in #213 for a ground-up redesign;
   then Goals #711–#740, removed in #769), with the lessons vertical
   (#273) in between, leaving the per-item `priority` flag (#765,
   `specs/priority-items.md`; priority UI and "neglected priority"
   signal tracked in #763 / #764). The vision/journey audit reopened the
   question: the ideal journey requires goals that *drive planning*, and
   the ruling is to rebuild them deliberately small: an outcome statement
   linked to library items with an optional target date, consumed by
   session planning, and none of the confidence/photo apparatus that sank
   the previous versions. The priority star stays as the zero-ceremony
   layer beneath. See VISION.md "The Scheduling Intelligence" and
   `docs/journeys.md` step 4.

6. **Lessons / photos / R2 surface (resolved 2026-07-14).** Rolled back:
   the lessons vertical was superseded by Goals in #711 (migrations
   0067–0068 dropped the lesson tables); Goals were then removed in #769
   (migrations 0081–0083). Nothing dormant remains, so #570 closes as
   part of the vision/journey audit. R2 photo storage hardening (#281) was
   closed as stale on 2026-09-06 and the R2 module deleted: the bucket was
   empty and photos are on-device files now.
