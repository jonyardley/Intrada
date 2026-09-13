# Android App Shell on the Shared Core

> Tier 3 (a second native shell on an unchanged Crux core; no core changes).
> Spec issue #1774. Nothing below has started: this is the plan a build
> phase claims against, playing the same role `specs/native-ios.md` plays
> for the iOS shell.

## Problem

intrada's only shell today is the native SwiftUI app on `intrada-core`. An
Android musician cannot use intrada at all. The core is a pure Crux app
with no I/O, and the iOS build already proved that a thin native shell over
the UniFFI bridge works. A second shell is a port of the bridge and the
screens, not a redesign of the domain.

## Approach

A native Android app in `android/` (Kotlin, Jetpack Compose) on the
unchanged `intrada-core`. No core changes: the same `Event` / `Effect` /
`ViewModel` contract that drives iOS drives Android too. The bridge itself
is cheap, because Crux 0.20's `crux_core::type_generation::facet::TypeRegistry`
carries a `kotlin(&config)` emitter next to the `swift(&config)` call
`codegen.rs` already uses. The real work is porting the shell: thirteen SwiftUI
screens plus their sheets and form scaffolds, the design system, the store loop, and the platform I/O:
persistence, singletons, the metronome, page OCR and the suggestion pass
over it, camera, screen wake lock, crash reporting.

## The Crux to Kotlin bridge

What the core already gives both shells:

- Four `Effect` variants cross the bridge: `Render`, `App`, `Persistence`,
  `Recognition`. Android fulfils the same four; none of them are iOS-shaped.
- `AppEffect` carries `SaveSessionInProgress`, `ClearSessionInProgress`,
  `SaveLibrarySort`, `SaveProfile`. All four are small-singleton writes, not
  relational data.
- No HTTP and no auth exist in core or shell today (the API was removed in
  #1746). Android needs neither on day one.
- The UniFFI surface is three calls (`update`, `resolve`, `view`) plus a
  constructor, and one free function, `sort_and_filter_picker_candidates`,
  with its `PickerCandidateArg` and `PickerSortArg` records. It is a plain
  call rather than an `Event` round trip because the picker sheet runs it on
  every keystroke (#1653); Android calls it the same way. iOS generates
  `ios/generated/SharedTypes` (the bincode types) and
  `ios/generated/IntradaCoreFFI` (the UniFFI bridge) from that surface;
  Android generates the Kotlin equivalents from the same `codegen.rs` binary.
  `intrada-ffi/src/lib.rs` pins uniffi 0.29.4 at compile time; the Kotlin
  bindgen must run at that same version or the bridge skews silently.

## How the iOS shell works today, for reference

The Swift store is `@Observable @MainActor`, with effect handlers running
off the main actor and hopping back to post results. Persistence is GRDB
raw SQL with positional columns; singletons and the crash-recovery session
blob (`ActiveSession`) live in `UserDefaults` as bincode bytes. The
metronome is an `AVAudioEngine` host-time click grid. Page OCR runs behind
the `Recognition` effect via Apple Vision, returning `RecognisedLine`s with
geometry; `PageSuggester` then runs Apple's on-device FoundationModels over
that text to suggest title, composer, tempo marking and bpm. The camera is a
`PageCamera` view; `ScreenWakeLock` keeps the player screen on; Sentry
reports crashes. Android ports each of these behind the same effect
contract, shown below.

## Layer mapping

| Layer | iOS today | Android | Note |
|-|-|-|-|
| Packaging | `cargo swift package` plus UniFFI Swift | `cargo ndk` building `arm64-v8a` and `x86_64` (the second for the emulator only) plus UniFFI bindgen's Kotlin target at uniffi 0.29.4, JNA at runtime | The same bridge calls either side, the picker function included. |
| Types | Swift `SharedTypes` | Kotlin `SharedTypes` via `typegen.kotlin(&config)` in the same `codegen.rs` binary, generated into `android/generated/` | Never hand-edited, on either shell. |
| Store | `@Observable @MainActor Store` | A Kotlin `Store` class exposing `StateFlow<ViewModel>`, effects dispatched on `Dispatchers.IO`, hopping back to `Main` | Same update, process, resolve loop. |
| Persistence | GRDB raw SQL, positional columns | `androidx.sqlite` with the bundled driver, raw SQL, the same schema and migration list | Not Room: Room wants entity classes, and the shell must stay a dumb pipe. |
| Singletons and crash blob | `UserDefaults` holding bincode bytes | `SharedPreferences` holding the same bincode bytes | Same key-bump rule when the blob shape changes (#1345). |
| Metronome | `AVAudioEngine` host-time click grid | `AudioTrack` streaming with clicks written at sample positions | Sample-accurate, not timer-driven. Hardest piece; the emulator cannot judge it. Oboe via the NDK only if a real device measures unacceptable latency. |
| Page OCR | Apple Vision behind `Recognition` | ML Kit on-device text recognition behind the same `Recognition` effect | ML Kit returns blocks; the shell splits them into `RecognisedLine`s with geometry. The core still decides field assignment. |
| Page suggestions | `PageSuggester` on FoundationModels | Open: no on-device model is assumed. Android ships OCR without the suggestion pass until one is chosen (Open questions). | The capture screen must read well with the fields left for the musician to fill. |
| Screen wake lock | `ScreenWakeLock` | `FLAG_KEEP_SCREEN_ON` on the player activity | |
| Crash reporting | Sentry | Sentry's Android SDK, DSN from the build config | Day-one quality, as on iOS. |
| Camera and photos | `PageCamera` view | CameraX plus the system Photo Picker | |
| Design system | `Theme.swift` tokens | A Compose theme object with the same token names | Built on Compose foundation with intrada's own look, not Material's. Back gesture and predictive back follow Android convention. |
| Screens | Thirteen SwiftUI screens plus the sheets and form scaffolds | Compose screens, one per iOS screen, same `ViewModel` projections | Navigation via Navigation Compose. |
| Tests | Swift Testing, snapshot, XCUITest | `kotlin.test`, Roborazzi snapshots on the JVM (no emulator needed), Compose UI tests on an emulator | |
| CI | macOS runners | Ubuntu runners for build, unit and Roborazzi; one emulator job for UI tests | Both shells gate every core change. |

## Working on a Mac with no Android device

Android Studio's `arm64` emulator on Apple silicon is enough for the
bridge, persistence, screens and snapshots. It cannot judge audio latency,
real camera OCR, or haptics: have a device (a Pixel 8a, or a second-hand
Pixel 7a) before the metronome phase starts.

Play Store, recalled and unverified (Open questions): the developer
account is a one-off fee. A brand new personal account must run a closed
test with 12 testers for 14 days before it can publish to production;
internal testing carries no such rule and is the TestFlight equivalent for
this build.

## Build phases

A review pass over the Swift shell, planned after v0.13 ships, runs
first: any rule it finds living in Swift rather than in `intrada-core`
moves to core before the port starts, or Android implements the same rule
twice. One instance is already known: the field assignment that follows
`PageSuggester`'s suggestions.

- **Phase A, bridge and boot.** `just android-gen`, the Kotlin `Store`, a
  read-only Library list rendering from the real `ViewModel`. Proves the
  toolchain end to end.
- **Phase B, persistence.** SQLite via `androidx.sqlite`, singletons, the
  crash blob; Library add and edit.
- **Phase C, practice.** Session builder, player, session clock, the
  metronome. Have the device in hand by this phase.
- **Phase D, capture and the rest.** Camera, OCR, analytics, profile,
  routines; then CI on Ubuntu and Play internal testing.

Each phase becomes its own issue when it starts; none exist yet.

## Recipes

Mirroring the `ios-*` set, not yet implemented: `android-typegen`,
`android-package`, `android-gen`, `android-run`, `android-test`,
`android-test-full`, `android-fmt`.

## Deliberately not doing

Kotlin Multiplatform, Flutter, or any shared UI layer: the iOS and Android
shells stay two native codebases on one core. Sync does not exist: the
API that carried it was removed in #1746, and any future sync starts from a
new spec (`docs/roadmap.md`); this spec adds none. A shared token source for
the two theme files is a later nicety, not a blocker.

Two shells means every core change regenerates two sets of bindings, and CI
gates both.

## Open questions

- **Play Store closed test rule.** To confirm at phase start: the 12
  testers and 14 days figure above was recalled, not checked against
  Play's current console.
- **ML Kit.** To confirm at phase start: the on-device text recognition
  API and its licensing for a non-subscription app need a fresh look
  before the capture phase, not now.
- **Page suggestions on Android.** Decided before the capture phase: an
  on-device model behind the same suggestion shape (Gemini Nano through ML
  Kit's GenAI APIs is the candidate, with narrow device support), or no
  suggestion pass on Android.
- **Roborazzi.** To confirm at phase start: version and CI setup
  (JVM-only snapshot rendering) need verifying against the Ubuntu runner
  image before Phase A lands.
