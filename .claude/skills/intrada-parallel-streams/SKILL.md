---
name: intrada-parallel-streams
description: Running more than one Claude Code session or subagent against this repo at once: the decoupled file set a second stream may use, any number of shell-only streams once each names its screens, the serialisation points never edited in parallel, one agent per vertical slice, worktree mechanics, and the definition of done. Read before starting a second stream or fanning out.
---

## Stream rules

The claim protocol in CLAUDE.md stops two streams building the same issue;
these rules stop two streams colliding in the same files. Evidence base: a
coupling analysis of 400 commits (2026-08): 31% of commits that touch
`crates/` also touch `ios/`. That figure is about commits that touch the
core; it says nothing about two changes that touch only Swift screens and no
crate, which is what most UX issues are (for example #1616, #1617, #1618 and
#1620).

- **One stream that touches `crates/intrada-core` or `crates/intrada-ffi`,
  plus any number of streams that touch only `ios/` and no crate.**
  Screen-only work carries none of the coupling the 31% figure measures, so
  two or more shell-only streams can run at once. Each shell-only stream
  names the screens it owns before it starts, so two streams cannot silently
  pick up the same file. This unlocks concurrent editing, not concurrent
  testing: every shell-only stream still queues at the test gate, one at a
  time, because test runs serialise on app launch whatever device they name
  (#1621; the mechanism and the recovery are in `docs/ios-testing.md`,
  "Running alongside another checkout"). A fast-tier run is well under a
  minute either way, so queuing costs little.
- A **stream that touches neither the core crates nor `ios/`** keeps to the
  decoupled set: `crates/intrada-api`, `docs/`, `specs/`, `design/`, or CI and
  tooling (`justfile`, `.github/workflows/`). An API task that needs a new
  domain field is a core change and joins the vertical stream.
- **Core serialisation points.** If your task and another live branch both
  touch one of these, serialise: `crates/intrada-core/src/app.rs`,
  `crates/intrada-core/src/domain/session.rs`, `Cargo.lock` (never pair
  anything with a dependency bump).
- **Shell serialisation points.** These four govern every screen, so a
  shell-only stream that touches one of them serialises with every other
  live stream, core or shell: `ios/IntradaTests/ScreenSnapshotTests.swift`,
  `ios/Intrada/DesignSystem/PreviewSupport.swift`,
  `ios/Intrada/DesignSystem/Theme.swift`, `ios/project.yml`.
- **Shell serialisation is common, not rare.** In the last 60 commits on
  `origin/main`, 17 touched only `ios/` and no crate; 8 of those 17 also
  touched `ios/IntradaTests/ScreenSnapshotTests.swift`, and 2 touched
  `ios/Intrada/DesignSystem/Theme.swift`. Check the four files above before
  assuming two shell-only streams are independent: about half the time they
  are not.
- **One worktree per session, started in it** (CLAUDE.md, Always step 3):
  `just worktree-new <name>` branches from fresh `origin/main` and seeds the
  warm `target/` and `ios/build` caches (#1205). Close the session when its
  task ships.
- **Once you have a worktree, edit only inside it.** On 2026-09-06 a session
  working in its own worktree also wrote the change into the main checkout,
  where another session nearly committed it into an unrelated PR. A green run
  proves nothing about whose work is in the tree: read the diff before
  `git add`, and never `git add -A` on a shared checkout.
- **Clear a conflicting PR by merging main in, never by rebasing**:
  `git fetch origin main && git merge origin/main && git push`. No tracked file
  is written by every PR any more, so a conflict means two branches really did
  touch the same code.
- **Dependent PRs stack natively, depth 2 max.** Open the child with base set to
  the parent's branch; GitHub retargets it when the parent merges. After the
  parent squash-merges: `git rebase --onto origin/main <parent-old-head>`.

## One agent per slice

**A vertical slice is one agent's job.** Never split core and iOS across two
agents on the same slice: in-session agent teams were tried on #1223 and
retired, because the shell teammate could not see the core invariant it needed
and wrote the worst bug in the PR (`docs/reference.md`).

Fan out only when the pieces are genuinely independent: no shared contract in
flight, nothing blocked on another's output. Good shapes: an audit or sweep
across many files, N independent approaches to one design question, unrelated
tasks in the decoupled set. One worktree per agent; the lead integrates; only
one agent runs iOS tests at a time; every fan-out task skips `just check` and
the suites, which the lead runs once at the end.

**Contract before code applies to one agent as much as several.** Pin the
Event/Effect/ViewModel shape for a slice before wiring either side.

## Definition of done, before requesting review

- [ ] `just check` green locally; `just ios-fmt-check` too if `ios/` touched
- [ ] Tests shipped with the new code
- [ ] PR opened through `/ship`; self-review comment posted
- [ ] Codecov compared against the PR's Coverage line (Tier 2+)
- [ ] Roadmap updated if a phase changed; deferred items tracked as issues
- [ ] A human reviews and merges. Agents never merge.
