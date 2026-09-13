# Background audio plugin (iOS)

> Spec for [intrada#309](https://github.com/jonyardley/intrada/issues/309) — P0 / parity-blocker for TestFlight + App Store.
> Tier 3 per CLAUDE.md (new Tauri plugin → IPC contract sensitivity override).
>
> Superseded 2026-09-13: the metronome keeps going in the background natively
> under #1399 (`UIBackgroundModes: audio`, no silent loop, no Now Playing),
> and the practice timer reads the wall clock, so nothing here is built.

## Problem

The Practice timer is the heart of the app. On iOS today it dies the moment the
screen locks or the user backgrounds the app. The current implementation is a
JS `setInterval` running inside the WKWebView (`session_timer.rs:53–66`), and
WKWebView is suspended when the app loses foreground — so the counter freezes,
the lock screen shows nothing, and a 30-minute practice session quietly stops
timing after a phone-times-out.

Until this is fixed, intrada is not a usable practice app on iOS. It cannot
ship to TestFlight or the App Store as-is.

## Goals

1. Practice session timer continues advancing while the screen is locked or
   the app is backgrounded, for the full duration of a session (typically
   ≤60 min).
2. Lock-screen Now Playing shows the current item title + elapsed time + the
   intrada logo, so the user can glance at the lock screen and see where they
   are.
3. Returning to the foreground reflects the correct elapsed time *immediately*,
   without a visible "the timer caught up" jump.
4. Audio session is released cleanly on session end (no stale "Intrada is
   playing" entry in Control Center).
5. Web build remains unaffected — the plugin is iOS-only, gated by platform.

## Non-goals

- Real audio playback. We are not playing music, metronome ticks, or guidance.
  The audio session is held open with silent audio purely to keep the OS from
  suspending the app.
- Lock-screen *controls* (play/pause/skip from the lock screen). Could come
  later but adds scope; the v1 lock screen is read-only Now Playing info.
- macOS support (Tauri 2 supports it but practice on Mac isn't a target).
- Android. Separate plugin if/when we get there.

## Approach

### Architecture

```text
┌──────────────────────────────────────────────────────────────────────┐
│  WKWebView (Leptos shell)                                            │
│                                                                      │
│   StartSession event                                                 │
│   ──► invoke('plugin:background-audio|begin_session', {…})           │
│                                                                      │
│   Render tick (Effect on visibility / wall clock)                    │
│   ──► elapsed = Date.now() − active.started_at                       │
│                                                                      │
│   Item advance / Finish / EndEarly                                   │
│   ──► invoke('plugin:background-audio|set_now_playing', {…})         │
│   ──► invoke('plugin:background-audio|end_session') on Finish        │
└──────────────────────────────────────────────────────────────────────┘
                              │ Tauri IPC
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  Rust plugin host (intrada-mobile/plugins/background-audio/)         │
│                                                                      │
│   #[tauri::command] begin_session, end_session, set_now_playing      │
│                                                                      │
│   Bridges to Swift via the Tauri 2 mobile plugin macro.              │
└──────────────────────────────────────────────────────────────────────┘
                              │ Swift bridge
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  Swift plugin (BackgroundAudioPlugin.swift)                          │
│                                                                      │
│   begin_session(title, started_at_ms):                               │
│     • AVAudioSession.sharedInstance()                                │
│         .setCategory(.playback, mode: .default,                      │
│                      options: .mixWithOthers)                        │
│     • setActive(true)                                                │
│     • Start silent loop on AVAudioPlayer                             │
│     • Seed MPNowPlayingInfoCenter (title + intrada artwork +         │
│       playbackState .playing)                                        │
│                                                                      │
│   set_now_playing(title, position_label, started_at_ms):             │
│     • Update title + subtitle + elapsed                              │
│     • Re-arm playbackState (item-change visual cue)                  │
│                                                                      │
│   end_session():                                                     │
│     • Stop silent player                                             │
│     • setActive(false, options: .notifyOthersOnDeactivation)         │
│     • Clear MPNowPlayingInfoCenter                                   │
└──────────────────────────────────────────────────────────────────────┘
```

### Why wall-clock, not tick-based

The current `elapsed_secs` increments via `setInterval`. With WebView
suspension that pattern is fundamentally broken — even with background audio
keeping the app alive, JS interval throttling on backgrounded WKWebViews is
unreliable. Better: store `started_at: chrono::DateTime<Utc>` in the active
session (already in core), and on every render derive
`elapsed = Utc::now().signed_duration_since(started_at)`. Robust to suspension,
to clock skew across app suspends, and to crash-recovery rehydration.

This is a single-file change in `crates/intrada-web/src/components/session_timer.rs`
(swap `setInterval` for an `Effect` driven by a coarse wall-clock signal that
ticks every 250ms via `requestAnimationFrame`-style polling, or on
`visibilitychange`). Implementation detail, but worth flagging — this change
is **necessary even on web** to make the timer survive tab backgrounding, so
it isn't iOS-only scope.

### Plugin surface

JS-side helper in `intrada-web/src/tauri_bindings/` (new module):

```rust
// Web: no-op. iOS: invoke the plugin.
pub async fn begin_session(title: &str, started_at_ms: i64);
pub async fn set_now_playing(title: &str, position_label: &str, started_at_ms: i64);
pub async fn end_session();
```

The helper checks `data-platform === "ios"` (already on `<html>`); on web it
returns immediately. Same shape as `haptics::haptic_*` wrappers today.

Call sites in the Practice flow:

| Trigger | Call |
|---|---|
| `SessionEvent::StartSession` lands → `vm.active_session.is_some()` flips | `begin_session(current_item_title, started_at)` |
| Item advance (`NextItem` / `SkipItem`) | `set_now_playing(new_title, "Item N of M", started_at)` |
| `FinishSession` / `EndSessionEarly` / `AbandonSession` | `end_session()` |

### Tauri command schema

```jsonc
// crates/intrada-mobile/plugins/background-audio/permissions/default.json
{
  "identifier": "default",
  "permissions": ["allow-begin-session", "allow-end-session", "allow-set-now-playing"]
}
```

Capabilities added to `crates/intrada-mobile/src-tauri/capabilities/` so the
WebView is allowed to invoke the three commands.

### Info.plist additions

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
<key>NSMicrophoneUsageDescription</key>
<!-- Not needed for playback-only; mentioning here so a future reviewer knows
     to keep it absent. -->
```

The Tauri iOS bundle config in `tauri.conf.json` will need an Info.plist
override mechanism; existing pattern is via the generated Xcode project under
`src-tauri/gen/apple/`. To verify during implementation.

## Key decisions

1. **Timer source of truth = wall clock**, not tick counter. (See architecture
   note above; required for correctness regardless of plugin work.)
2. **Plugin is JS-callable only**, not exposed through Crux. The plugin is a
   side-effect (audio session lifecycle, lock-screen UI) tied to the Tauri
   shell's platform reality, not domain logic. Crux core stays clean of
   platform calls — it just tracks `started_at` and emits the events the shell
   reacts to.
3. **Silent audio loop** vs **AVAudioEngine generated silence**: pick the
   simplest — a 1-second looped silent `.wav` shipped in the plugin bundle,
   played on `AVAudioPlayer` with `numberOfLoops = -1`. Lower implementation
   risk than touching AVAudioEngine.
4. **Audio session category `.playback` with `.mixWithOthers`** — so the user
   can keep their own backing track / metronome / streaming app running
   alongside their practice session. Critical for the actual use case
   ("practice along with a recording").
5. **Tauri 2 mobile plugin pattern** (Rust + Swift) over a pure-Tauri JS
   plugin. iOS-specific behaviour requires native APIs.
6. **No Pencil design needed** for v1. The UI surface is just the existing
   timer behaviour-corrected, plus the iOS Now Playing card which Apple
   provides chrome for. Revisit if v2 adds custom lock-screen controls.

## Open questions

1. **Silent-audio file format & size.** 1s mono 44.1kHz silence is ~88KB in
   16-bit PCM, ~6KB compressed in AAC. Either is fine; AAC reduces bundle
   bloat. Resolve by trying both and picking what the iOS audio player
   handles without dropouts on session boundaries.
2. **Re-arming on phone call interrupts.** When a call comes in, iOS suspends
   the audio session. Need to handle `AVAudioSession.interruptionNotification`
   to reactivate on resume — otherwise the timer stops mid-session. Spec'd as
   in-scope; flag for testing.
3. **`MPNowPlayingInfoCenter.shared().nowPlayingInfo` updates from
   background.** Some Apple sample code does these on the main queue only —
   verify whether our plugin's update path is main-queue-safe.
4. **iPad behaviour.** On iPad with Slide Over / Split View, the app may not
   "background" in the same way. Check whether background audio mode is
   needed at all there, or whether the timer just keeps running because the
   WebView isn't suspended.
5. **Sentry instrumentation for plugin events.** Want spans around
   `begin_session` / `end_session` to catch failures on real devices. Wire
   into the existing `_sentry_guard` setup in `lib.rs`.

## Phasing

Spec → Plan → implement in 4 chunks, each its own PR:

1. **Phase A — wall-clock timer** (small). Replace `setInterval` with
   wall-clock derive. No iOS work; ships to web too. Validates the timer
   survives web tab backgrounding (Chrome throttles `setInterval` to 1Hz on
   backgrounded tabs — likely a latent bug today).
2. **Phase B — plugin scaffold** (medium). Empty Tauri 2 plugin under
   `crates/intrada-mobile/plugins/background-audio/` with the three commands
   stubbed (return Ok, do nothing). JS bindings module. iOS build still
   compiles. No behaviour change yet — just the IPC channel proven.
3. **Phase C — Swift implementation** (large; the bulk of the work).
   AVAudioSession + silent loop + MPNowPlayingInfoCenter. Behaviour testable
   on physical device only — see CLAUDE.md "test on device" rule. Includes
   interruption handling.
4. **Phase D — instrumentation + polish** (small). Sentry spans, error
   surfaces in `vm.error` for plugin failures, end-of-session cleanup audit.

## Acceptance criteria

- [ ] 30-minute timed practice session continues advancing while the iPhone
      is locked, verified on a physical device (not simulator).
- [ ] Lock screen shows Now Playing with item title, position label
      (`Item N of M`), and elapsed time advancing.
- [ ] Bringing the app back to foreground after 5 minutes locked shows the
      correct elapsed time within 1 second of the wall-clock truth.
- [ ] Phone call mid-session: timer pauses (real audio session interruption),
      resumes correctly after the call ends.
- [ ] Music app playing in background continues to play during practice
      session (mixWithOthers verified).
- [ ] On `FinishSession` / `EndSessionEarly` / app crash: audio session is
      released, lock-screen Now Playing entry disappears, Control Center has
      no stale Intrada entry.
- [ ] Web build: dev server, web tests, e2e all pass; no plugin imports leak
      into the web bundle.

## References

- Tauri 2 mobile plugin docs: <https://v2.tauri.app/develop/plugins/develop-mobile/>
- AVAudioSession: <https://developer.apple.com/documentation/avfaudio/avaudiosession>
- MPNowPlayingInfoCenter: <https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter>
- Existing plugins in this repo: `tauri-plugin-haptics`, `tauri-plugin-deep-link`
  (both in `crates/intrada-mobile/src-tauri/Cargo.toml`)
