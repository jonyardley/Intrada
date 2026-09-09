# Where we are

*Orientation, hand-written, changed when the phase or the release changes and
not otherwise — so no two branches ever edit it at once. For what is in flight
right now, run `just status`; it reads GitHub, which is the source of truth.
Direction and phases: [`roadmap.md`](roadmap.md).*

**v0.10.0 is on TestFlight (2026-09-09), as build 19.** Its headline is
capture: add a piece with its chord chart and its exercises in one pass, and a
refusal that marks the field, the row or the chart at fault rather than only
saying what is wrong (#1390 and #1595,
[`specs/one-pass-create.md`](../specs/one-pass-create.md)). Alongside it: the
whole Focus Player round (the overall session timer, the resident pass counter,
and a click that sounds chosen beats of a chosen bar), one tap into the starred
set on Practice (#981), a note per item on Session Complete and a past session
opened from history (#1370, #1371), and the page camera fixes.

**It is also the first build that reports its crashes.** Every earlier
TestFlight build shipped with Sentry switched off, because the key was never
handed to the release build (#1553); a tagged release now refuses to build
without it, and each one gets a Sentry release of its own, named for the build
a tester is running. Debug symbols are still not uploaded, so a crash names the
build and not the line (#1610).

v0.9.0 (2026-09-02) was the photo release: photograph the page and the add form
fills itself, with the on-device model picking the fields where Apple
Intelligence is available (phases A to C of
[`specs/piece-from-photo.md`](../specs/piece-from-photo.md); phase D, a chord
chart from a photo, is not started).

**Phase R ([`rethink-plan.md`](rethink-plan.md)) has met its exit criteria.**
Stage 4 chose the direction on 2026-09-07 and its first slice shipped in this
release, so the phase's own test, a direction with a Tier 3 spec and a slice
of it shipped, is answered. Its Stage 3 work was the audit backlog in
[`audit-2026-08.md`](audit-2026-08.md), the definitive reference for what the
audit found and the order it ran in. **Every phase of that backlog is
closed**: Phase 3 finished on 2026-09-07 when #1585 shipped
per-item notes on Session Complete (#1370), after the quick-add section (#1362)
and the history detail view (#1371, in #1580).

**The Focus Player round shipped on 2026-09-03** and closed Phase 4: the
overall session timer (#1364), the resident pass counter (#1367, core then
shell), and a click that sounds chosen beats of a chosen bar without lying
about the tempo (#1499, core then shell). One Claude Design pass, one Tier 3
spec ([`specs/practice-instruments.md`](../specs/practice-instruments.md)),
six PRs. Two of the things it deliberately left behind are still tracked: the
declared tempo of a quaver-metre piece still reads as a crotchet (#1510), and
sheets still hand-mirror ranges the core validates (#1512). The idle timer
(#1513) was fixed on 2026-09-04.

The next major direction was decided on 2026-09-07 (Stage 4 of the rethink
plan): **push the capture line**. The weekly-lesson loop (#1087) turned out to
be three quarters shipped, since per-piece tracking (#1081), the Up next card
(#1082) and exercise steps (#1083) have all landed, so its only unbuilt part
was entry, and entry is a capture problem. Quick lesson entry (#1080) closes
into one-pass create (#1390), specced in
[`specs/one-pass-create.md`](../specs/one-pass-create.md); no lesson entity
gets built.
