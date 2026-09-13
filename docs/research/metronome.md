# Research note: the metronome, with tempo as a tracked unit of measure

*Stage 4.1 of [`docs/rethink-plan.md`](../rethink-plan.md). Candidate: #1366
(roadmap Open Question 1, answered 2026-08-14). Evidence and shape only; no
comparison against the other candidates and no recommendation. 2026-08-14.*

## 1. What it is

An audible click inside the Focus Player, plus tempo captured per item per
session, plus tempo-over-time analytics. Three linked claims, in ascending
order of interest:

- **The click** — a metronome in the live view, defaulting to the item's
  declared tempo target. Table stakes: every practice app has one.
- **The capture** — the tempo you actually practised at lands in the session
  record with one gesture, ideally pre-filled from the click setting.
- **The measurement** — tempo per item accumulates into a trend against the
  target. This is the differentiating claim: tempo is one of the very few
  honestly objective proxies for technical progress the app can record
  without machine listening.

## 2. The user problem

- **Leaving the app mid-session.** The Focus Player runs a timer and rep
  counts, but the moment a musician wants a click they switch to a separate
  metronome app, losing the timer surface and any chance of the practised
  tempo being recorded. The tool that structures the session is not the tool
  keeping time inside it.
- **Tempo progress is invisible.** Motor consolidation means improvement lags
  the session that produced it
  ([`docs/research-foundation.md`](../research-foundation.md) §8, Walker &
  Stickgold 2004), so musicians under-perceive their own progress.
  Research-foundation calls surfacing that trajectory "Intrada's core design
  opportunity", and [`VISION.md`](../../VISION.md) promises exactly this
  evidence: "bridge steady at 96".
- **Journeys served.** [`docs/journeys.md`](../journeys.md) step 1 (enrich a
  piece with tempo), step 3 (track each exercise across score, tempo, reps;
  flagged Partial, "tempo has no iOS input", now only half true, see §3), and
  the Practice + Track pillars: the click serves Practice, the measurement
  serves Track.

## 3. What exists today

The starting point is much richer than issue #1366 implies. Tempo is already
threaded through the core end to end:

- **Target tempo per item** — `Item.tempo: Option<Tempo>` with
  `{marking, bpm}` (`crates/intrada-core/src/domain/item.rs:54`,
  `domain/types.rs:36`), editable in the item form, shown on
  `LibraryDetailScreen`.
- **Achieved tempo per entry per session** —
  `SetlistEntry.achieved_tempo: Option<u16>` (`domain/session.rs:80`),
  written by `SessionEvent::UpdateEntryTempo` with range validation
  (`validation.rs:277`). Persists inside the session record via the existing
  `SaveSession` persistence op: **per-item-per-session tempo needs no new
  schema**.
- **Capture UI exists** — the Focus Player's hand-off reflection sheet has a
  `TempoStepper` seeded from the item's target and sends `updateEntryTempo`
  (`ios/Intrada/Views/Screens/FocusPlayerScreen.swift:264`,
  `ReflectionSheet.swift`). It is hidden when the item declares no tempo
  target, so tempo can only be logged against pre-declared targets.
- **History is computed but never rendered** — the core derives
  `tempo_history: Vec<TempoHistoryEntry>` and `latest_tempo` per item from
  the session archive (`app.rs:773-844`, `model.rs:379-399`) and exposes
  `latest_achieved_tempo` on items, but no Swift screen reads any of it
  (only `PreviewSupport.swift` constructs it). The Track half of the feature
  is a dark projection waiting for a surface.
- **The recoverable click** — `ClickEngine.swift` (293 lines) plus
  `ClickEngineTests.swift` (218 lines), removed in #1344, recoverable from
  `071b85b` (the parent of revert commit `8af4891`, matching the roadmap's
  pointer) at `ios/Intrada/Coach/ClickEngine.swift`.
  Concretely: an `AVAudioEngine`/`AVAudioPlayerNode` metronome with
  synthesised buffers (600/1000/1500 Hz for count-in/click/accent),
  host-time scheduling compensated for `outputLatency`, a rolling 64-beat
  window topped up by a 10 ms poll (immune to iOS timer coalescing),
  count-in and per-beat callbacks carrying `hostTime`, interruption
  observation, and a pure `buildSchedule` testable without a live engine
  (`e85cb2c`, #1282). This is a production-quality engine, not a spike.
- **Background audio groundwork**: the reference `BackgroundAudioPlugin.swift`
  (preserved from the Tauri shell, removed in #1745 and recoverable from git
  history): `AVAudioSession` `.playback` + `.mixWithOthers`, a silent-loop
  keep-alive so iOS does not suspend timers in the background, interruption
  re-arm, and `MPNowPlayingInfoCenter` seeding. Spec:
  `specs/background-audio-plugin.md`.
  Shipped natively under #1399 without the silent loop: the running
  `AVAudioEngine` under `UIBackgroundModes: audio` is the keep-alive.

**Genuinely new:** the click wired into the builder's Focus Player rather
than the deleted coach loop; a rendered tempo trend (item detail and/or
Track); capture without a pre-declared target; and, only if per-rep or
within-session tempo granularity is wanted, a schema addition (see §5).

## 4. Pedagogy evidence

The click itself needs no defence; the interesting claims are about tempo as
a *practice variable* and as a *measure*.

- **Tempo as an objective measure.** Self-scores are subjective and drift;
  minutes measure input, not output. The BPM at which a defined passage is
  playable is cheap to record, monotone-comparable over time, and meaningful
  to the musician in their own vocabulary. The transfer literature backs the
  underlying assumption that trained maximum speed genuinely rises with
  practice and persists: submaximal-speed piano practice progressively
  increased maximum speed of the trained sequence, retained two months later
  and largely hand-specific ([Transfer of piano practice in fast performance
  of skilled finger movements](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4228459/)).
  The caveat: tempo is only honest with an accuracy criterion attached, and
  in Intrada that criterion is the user's own attestation, not a gate.
- **Gradual increase vs variable tempo: contested.** The traditional
  slow-then-notch-up ladder is prevalent and has real cognitive functions
  (accuracy, problem-solving, load management) but musicians overuse it and
  understand it poorly ([Allingham & Wöllner 2022](https://journals.sagepub.com/doi/10.1177/03057356211073481);
  [2023 follow-up](https://journals.sagepub.com/doi/10.1177/03057356221129650)).
  Against the always-slow dogma: tempo change can reorganise the movement
  itself, so slow practice does not automatically transfer to speed
  ([Trapkus 2023, the case for rehearsing at performance tempo](https://doi.org/10.1177/00031313231166022);
  practitioner versions at [Bulletproof Musician](https://bulletproofmusician.com/jason-sulliman-on-why-fast-practice-can-be-more-efficient-and-effective-than-slow-practice/)
  and [Fundamentals of Piano Practice §1.19](https://fundamentals-of-piano-practice.readthedocs.io/chapter1/ch1_procedures/II.19.html)
  on metronome "speed walls").
- **Variable practice.** Variability-of-practice work with pianists found
  the variable-target group retained better after 24 h than fixed-target
  practice ([Frontiers 2014 pilot](https://www.frontiersin.org/articles/10.3389/fnhum.2014.00598)),
  consistent with the contextual-interference evidence already in
  research-foundation §2 (Carter & Grahn 2016; Mathias & Goldman 2025). But
  a dissociation matters for tempo specifically: motor-skill gains showed
  contextual-interference benefits *within* a common tempo, not across
  changing tempi ([PLOS One 2018](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0193580)).
  So "randomise the tempo" is not a safe default prescription.
- **Framing that survives the contest.** The challenge point framework
  ([Guadagnoli & Lee 2004](https://www.researchgate.net/publication/8574634_Challenge_Point_A_Framework_for_Conceptualizing_the_Effects_of_Various_Practice_Conditions_in_Motor_Learning);
  [2025 scoping review](https://www.tandfonline.com/doi/full/10.1080/00222895.2025.2508283))
  says optimal difficulty is per-performer and per-task, which argues for the
  app *measuring* tempo and leaving the strategy to the musician, exactly the
  notebook posture. Prescribing a ladder would pick a side in a live
  scientific dispute; recording where the musician chose to work does not.
- **What competitors do.** Soundbrenner pairs its metronome with a practice
  tracker and incremental tempo change but tracks hours and streaks, not
  tempo as a per-piece progress measure
  ([The Metronome by Soundbrenner](https://apps.apple.com/us/app/the-metronome-by-soundbrenner/id1048954353)).
  Research-foundation's competitor table lists metronomes (Instrumentive) as
  a feature, never as a measurement instrument. Tempo-trend-per-item appears
  to be genuinely unoccupied ground.

## 5. Shape sketch

- **Slice 1: the click (Tier 2, iOS-only, zero schema).** Port
  `ClickEngine` (`ios/Intrada/Core/ClickEngine.swift`) into the Focus
  Player; port the audio-session handling from the reference
  `BackgroundAudioPlugin.swift`
  (removed in #1745, recoverable from git history).
  BPM seeds from `current_item_tempo_bpm` (already in the ViewModel); the
  click setting is UI interaction state, so the dumb-pipe rule is untouched.
  Independently valuable: no more leaving the app for a click.
- **Slice 2 — capture closes the loop (Tier 2, small core touch).** The
  reflection stepper pre-fills from the last click tempo used, and the
  stepper shows even when the item has no declared target (today it hides).
  Uses the existing `UpdateEntryTempo`; core change limited to relaxing the
  target-only affordance.
- **Slice 3 — the trend surface (Tier 2).** Render the already-computed
  `tempo_history` on item detail (sparkline against target bpm) and let the
  Track pillar consume it. Core work is projection-shaping only; remember
  the two-PR-split lesson that the core PR must ship the ViewModel
  projections the screens read (#1256 Phase C).
- **Tier 3 only if the granularity grows.** Per-rep tempo events, multiple
  tempos per entry per session, or click configuration persisted per item
  (time signature, subdivision, accent pattern as new columns) would touch
  core + schema + codec together and deserve the short spec #1366 asks for.
  The per-session-per-item version does not: the issue's Tier-3 instinct
  overestimates the schema gap because the tempo plumbing already landed.

## 6. Risks and open questions

- **The audio quality bar.** A jittery click is worse than none; musicians
  notice single-digit milliseconds. Timer-driven clicks audibly drift, which
  is why the recovered engine's host-time `scheduleBuffer` approach (Apple's
  own [HelloMetronome](https://developer.apple.com/library/archive/samplecode/HelloMetronome/Introduction/Intro.html)
  pattern; see also [AVAudioPlayerNode timing](https://medium.com/@mehsamadi/making-sense-of-time-in-avaudioplayernode-475853f84eb6))
  must be kept, not simplified. Verification is on-device by ear; snapshot
  tests cannot cover it, and the simulator's audio latency lies.
- **Background audio and the session timer.** The silent-loop keep-alive has
  battery cost; interruptions (calls, other audio), route changes (AirPods),
  `.mixWithOthers` vs ducking, and interplay with a future Live Activity all
  need the Reference README's groundwork rather than a fresh guess.
- **Crash-recovery blob hazard.** Any new field reaching `ActiveSession`'s
  transitive graph (a current-click-bpm, say) silently invalidates every
  crash-recovery blob (#1223/#1244/#1256); until the wire-pin port (#1345)
  lands, such a change must bump the UserDefaults key. Cheapest dodge: keep
  click state out of the snapshot graph entirely.
- **Scoring + tempo coupling (roadmap Q3) is still open.** Whether every
  mastery rating wants a tempo, or tempo stays optional, decides what the
  trend chart can honestly claim. The analytics slice should not ship before
  Q3 is answered, or the chart mixes incomparable points.
- **Scope creep towards the coach.** Tempo targets with escalation rungs,
  "three clean at 96 then move up", gating advancement on the click: that is
  the reverted coach loop (`docs/rebuild-review.md`) rebuilt under a new
  name, and the parser-gate incident (#1256) shows how tempo rules go wrong
  quietly. The discipline is measurement without prescription: the app
  records the tempo, the musician owns the strategy.
- **Honesty of the measure.** Achieved tempo is self-reported and carries no
  accuracy criterion. That is acceptable for a notebook (the score is
  self-reported too) but the trend surface must present it as "tempo you
  logged", not as verified attainment.

## 7. Sources

Repo: [`docs/roadmap.md`](../roadmap.md) (Open Questions 1, 3) ·
[#1366](https://github.com/jonyardley/intrada/issues/1366) ·
[`docs/research-foundation.md`](../research-foundation.md) ·
[`docs/journeys.md`](../journeys.md) · [`VISION.md`](../../VISION.md) ·
[`docs/rebuild-review.md`](../rebuild-review.md) ·
`ios/Intrada/Core/ClickEngine.swift` (the click, live in the tree) ·
`git log --diff-filter=D -- ios/Reference/` (the reference Swift, removed in
#1745; recover it from the commit before that change in `main`'s history).

Web:

- Guadagnoli & Lee (2004), challenge point framework —
  <https://www.researchgate.net/publication/8574634_Challenge_Point_A_Framework_for_Conceptualizing_the_Effects_of_Various_Practice_Conditions_in_Motor_Learning>
- Challenge Accepted: scoping review of challenge point applications (2025) —
  <https://www.tandfonline.com/doi/full/10.1080/00222895.2025.2508283>
- Transfer of piano practice in fast performance of skilled finger movements —
  <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4228459/>
- Effects of variability of practice in music: pilot study in pianists —
  <https://www.frontiersin.org/articles/10.3389/fnhum.2014.00598>
- Dissociable effects of practice variability on motor and timing skills —
  <https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0193580>
- Allingham & Wöllner (2022), slow practice and tempo-management strategies —
  <https://journals.sagepub.com/doi/10.1177/03057356211073481>
- Allingham & Wöllner (2023), perceived uses and limitations of slow practice —
  <https://journals.sagepub.com/doi/10.1177/03057356221129650>
- Trapkus (2023), the case for rehearsing at performance tempo —
  <https://doi.org/10.1177/00031313231166022>
- Bulletproof Musician on fast, at-tempo practice —
  <https://bulletproofmusician.com/jason-sulliman-on-why-fast-practice-can-be-more-efficient-and-effective-than-slow-practice/>
- Fundamentals of Piano Practice §1.19, accurate tempo and the metronome —
  <https://fundamentals-of-piano-practice.readthedocs.io/chapter1/ch1_procedures/II.19.html>
- Apple HelloMetronome sample (AVAudioEngine scheduling pattern) —
  <https://developer.apple.com/library/archive/samplecode/HelloMetronome/Introduction/Intro.html>
- Making sense of time in AVAudioPlayerNode —
  <https://medium.com/@mehsamadi/making-sense-of-time-in-avaudioplayernode-475853f84eb6>
- Sample-accurate AVAudioEngine metronome (reference implementation) —
  <https://github.com/Alexander-Nagel/Metronome-using-AVAudioEngine>
- The Metronome by Soundbrenner (competitor: metronome + practice tracker) —
  <https://apps.apple.com/us/app/the-metronome-by-soundbrenner/id1048954353>
