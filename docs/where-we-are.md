# Where we are

*Orientation, hand-written, changed when the phase or the release changes and
not otherwise — so no two branches ever edit it at once. For what is in flight
right now, run `just status`; it reads GitHub, which is the source of truth.
Direction and phases: [`roadmap.md`](roadmap.md).*

**v0.9.0 is on TestFlight (2026-09-02).** Its headline is adding a piece from
a photo: photograph the page and the add form fills itself, with the on-device
model picking the fields where Apple Intelligence is available (phases A to C
of [`specs/piece-from-photo.md`](../specs/piece-from-photo.md); phase D, a
chord chart from a photo, is not started). Alongside it: the metronome click
and the tempo trend, the "Used in" card on exercises, and a run of Library
sorting and accessibility fixes.

Phase R ([`rethink-plan.md`](rethink-plan.md)) is in Stage 3, working the
audit backlog in [`audit-2026-08.md`](audit-2026-08.md), the definitive
reference for what the audit found and the order it runs in. **Every phase of
that backlog is now closed**: Phase 3 finished on 2026-09-07 when #1585 shipped
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
