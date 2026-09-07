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
reference for what the audit found and the order it runs in. Phases 1, 2 and
4 are closed; Phase 3 has the Session Complete notes (#1370) outstanding,
now that #1580 has shipped the history detail view (#1371).

**The Focus Player round shipped on 2026-09-03** and closed Phase 4: the
overall session timer (#1364), the resident pass counter (#1367, core then
shell), and a click that sounds chosen beats of a chosen bar without lying
about the tempo (#1499, core then shell). One Claude Design pass, one Tier 3
spec ([`specs/practice-instruments.md`](../specs/practice-instruments.md)),
six PRs. What it deliberately left behind is tracked: the declared tempo of a
quaver-metre piece still reads as a crotchet (#1510), sheets still hand-mirror
ranges the core validates (#1512), and nothing holds the idle timer, so the
screen sleeps mid-practice (#1513).

The next major direction stays open (Stage 4 of the rethink plan). The capture
line has earned its keep — the on-device page read was validated on device on
2026-09-02 — but nothing is decided between pushing capture further and the
weekly-lesson loop (#1087).
