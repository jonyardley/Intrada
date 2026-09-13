# Native iOS Shell (SwiftUI + Crux)

> Tier 3 (Crux FFI bridge + new persistence/sync capability, multi-week,
> spans core + a net-new native shell). The original spec rode with the Phase A
> branch; the 2026-06-01 **offline-first / paid-sync reframe** (see Decisions
> log) rides with the Phase B (B1) branch, per CLAUDE.md. Reverses PR #382,
> which removed the prior SwiftUI shell — the "app-first + offline-first"
> framing below is the deliberate answer to *why reverse it*.

## Problem

intrada's iOS app today is a Tauri 2 WKWebView wrapping the Leptos web shell.
At the piano — the primary place the app is used — a webview doesn't feel like
a native instrument-side tool: scroll/gesture/transition fidelity, launch feel,
and platform affordances all read as "web in a frame."

We have a pure Crux (Rust) core that already owns all business logic. We have
never actually used Crux as designed — a pure core with a *thin native shell*
over FFI/typegen. The Tauri shell skips that step. Going native iOS finally
exercises the Crux payoff and sets up native Android later on the same core.

A complete native SwiftUI shell **already existed and was removed in PR #382**
(`bdd815c..84b26d6`) — it reached Plan/Practice/Track + iPad parity over
HTTP-through-core. So this is **resurrect-and-modernize, not greenfield**: the
core is fully intact and the old pipeline is recoverable via `git show
84b26d6^:<path>`.

## Approach

Resurrect the proven #382 architecture and modernize it (Swift 6 strict
concurrency, `@Observable`, NavigationStack/SplitView, Swift Testing, iOS 26
SDK), while adding the one thing #382 never had: **local-first persistence**.

Strategic decisions (settled; not re-litigated here):

- **App-first.** Native iOS now, native Android later — both on the shared
  Crux core. Web stays on Leptos, untouched. Web's data model is decided later.
- **Offline-first is the product model.** On-device SQLite is the source of
  truth. The app is fully functional with **no network and no account** — local
  writes always succeed. The existing Axum+Turso backend demotes from live data
  source to an **optional sync target**.
- **Sync is the paid tier.** Free tier = a complete single-device offline app.
  Paid tier (subscription) = multi-device sync + backup/restore. The backend
  earns its keep as a sync/backup service, not as the data source. **Auth is
  therefore optional** — only required to enable sync.
- **Sync scope is deliberately small.** Single-user, multi-device,
  **last-write-wins on `updated_at` — not CRDTs**, not multi-user collaboration.
- **Rethink as we build.** The native build is **not** a 1:1 port of the web
  app. Each feature area gets a fresh design pass (Pencil + HIG, grounded in how
  the app is actually used at the piano — see `docs/design-principles.md`)
  *before* implementation. The Crux domain model stays the stable foundation;
  the UX/feature framing is open to reinvention per pillar.

### What offline-first changes about "robustness"

Online-first, a failed mutation `POST` needs a per-action error banner + rollback
(tracked as [#800]). Offline-first, **local writes don't fail** — there is no
per-action HTTP to roll back. Failures live only at the *sync* layer, where they
are background and retryable, not per-tap banners. So #800 is **parked**: a
lighter error-surface folds into the Phase D sync work, not the mutation path.

[#800]: https://github.com/jonyardley/intrada/issues/800

## The Crux → Swift bridge

The core stays pure and synchronous; all I/O is an `Effect` the shell fulfils.
The shell is a **dumb pipe** — it owns zero domain logic (see CLAUDE.md "Native
iOS Shell" section).

- **FFI:** UniFFI exposes the three byte-buffer bridge methods
  (`update` / `resolve` / `view`, unified in Crux 0.17). Bytes in, bytes out.
- **Typegen:** `facet-generate` (≥0.17) + the `facet_typegen` feature on
  `crux_core` 0.18 generates a Swift package of `Event` / `Effect` /
  `ViewModel` + domain types and their bincode (BCS) serializers. The core
  types in `app.rs` (`Event`, `AppEffect`, and `Effect` via
  `#[effect(facet_typegen)]`) get their `#[derive(Facet)]` (+ `#[repr(C)]` on
  enums) restored behind the feature (they were stripped in #382).
- **Packaging:** **spike `cargo-swift`** (the Crux book's current documented
  path: `cargo-swift` + `xcodegen` + `just`) which produces a Swift package
  wrapping the compiled static lib. **Fallback:** revive the hand-rolled
  `scripts/build-ios.sh` from #382 if cargo-swift fights us. Decision resolved
  by the Phase A spike.
- **HTTP-through-core:** the `Http` effect carries a fully-built `HttpRequest`
  (url/method/headers/body); the Swift shell runs `URLSession`, adds the
  platform auth header (Clerk JWT / iOS PAT), handles the 401-retry, and
  resolves the response bytes. No domain types cross the boundary as anything
  but bytes.

### Known build hazard — UniFFI #2818

UniFFI-generated Swift fails to compile under Xcode 26 / Swift 6.2 when the
module defaults to `MainActor` isolation ([mozilla/uniffi-rs#2818], open since
Feb 2026). Mitigation baked into the build recipe: keep the generated `Shared`
package **non-MainActor-defaulted**, or post-process the generated Swift to
prepend `nonisolated` (a `just` step) until UniFFI ships a config option.

[mozilla/uniffi-rs#2818]: https://github.com/mozilla/uniffi-rs/issues/2818

## NEW capability — local-first persistence + sync

Crux removed the Capability API in 0.17 (the core already uses `Command`
exclusively — see `Command::all` / `Command::notify_shell` in `app.rs`). So
persistence is **not** a custom capability; it's a **custom `Effect` driven by
`Command`**.

- **Core side:** add a `Persistence` effect variant carrying typed
  query/mutation operations (an `Operation` whose `Output` is the typed result
  — same shape as `AppEffect`). The core decides *what* to read/write and runs
  **LWW reconciliation**; that logic lives in core so it's shareable to Android.
- **Shell side:** **GRDB owns the real SQLite tables** and fulfils the
  persistence effect off the main actor, returning serialized rows. `crux_kv`
  is used **only** for small singletons (settings, `session-in-progress`
  crash-recovery), never for relational data.
- **Sync (LWW) design, with the known pitfalls handled:**
  - **Server-authoritative `updated_at`** stamped on write (avoids device
    clock skew silently losing newer edits).
  - **Tombstones** (`deleted_at`) compared under the same LWW rule (avoids the
    delete-vs-update resurrection race), GC'd after a safe window.
  - **Deterministic tiebreak** on equal timestamps (compare ulid / device id)
    so all devices converge on the same winner.
  - **Row-level** LWW (documented; field-level is out of scope for a
    single-user practice app).
  - Offline-first: writes apply locally immediately; sync is deferred and
    retried.

### Sync engine — evaluated 2026-06 (deep-research, verified)

We surveyed the landscape before committing. Outcome: **build the local store
sync-agnostic now; defer the engine; lean roll-our-own LWW when we build sync.**

- **Turso/libSQL offline-sync** — the tempting "we already use Turso" path — is
  **still beta in 2026 with a documented "data loss is possible" warning**, and
  Turso is mid-rewrite (Rust "Turso DB" also beta). Disqualifying for a *paid*
  tier today. (Its default row-level Last-Push-Wins *does* match our LWW, so it
  stays a candidate once it GAs with durability.)
- **Automerge 3.0** (CRDT, Rust-native; `autosurgeon` reconcile in the core) is
  the strongest *conceptual* fit and the fallback if we ever want CRDT-grade
  resilience — but its **Swift sync layer is alpha/stale**, so it'd mean driving
  sync from the Rust core with hand-rolled Swift glue. Not now.
- **CloudKit / SwiftData** — free (can't monetize), iOS-only (breaks Android),
  and bypasses the core (Swift owns the schema). Architecturally out.
- **PowerSync / ElectricSQL** — assume the client owns the DB in Swift/JS; poor
  fit for a Rust core. Out.
- **Decision:** the local SQLite schema bakes in `updated_at` + soft-delete
  tombstones from B2 so **both** survivors — custom LWW-to-Turso *or*
  Automerge-in-the-core — can sit on it later. We commit to neither yet. The
  biggest risk to avoid: shipping Turso's offline-sync beta to paying users.

## Phased plan

- **Phase 0 (done):** focus-mode CI + iOS agent tooling.
- **Phase A (done):** `crates/intrada-ffi` (UniFFI + facet typegen), the
  cargo-swift pipeline, and a minimal SwiftUI app rendering the `ViewModel`.
  swift-snapshot-testing, Sentry, and accessibility baked in from day one.
- **Phase C-early (done — but online-first):** Library screens — list, detail,
  add, edit, delete — plus filter-from-ViewModel, fonts + Dynamic Type, and a
  Store effect-loop test harness. Built over HTTP-through-core *ahead* of
  persistence. **Phase B now retrofits local-first underneath these screens.**
- **Phase B (ACTIVE — the critical path):** make the app genuinely offline,
  built as small reviewable increments:
  - **B1** — `Persistence` Effect *contract*: typed query/mutation ops in the
    core (TDD); the Swift shell stubs it. No behaviour change — just the pipe.
  - **B2** — GRDB store: the shell fulfils the effect against real SQLite;
    schema + sequential migrations (mirroring the API's migration discipline).
    Schema is **sync-agnostic** — `updated_at` + soft-delete tombstone columns
    baked in now so a later sync engine can sit on it (see Sync engine above).
  - **B3a (done)** — write-through: item create/update/delete also persist to
    the local store (creates/updates on their server-confirmed event, deletes
    optimistically). Additive — web ignores the Persistence effect; iOS
    populates the store. Reads still come from HTTP.
  - **B3b (done — the local-first flip)** — seed-empty couples reads and writes,
    so this did **both** (absorbing the old B4): a per-shell `local_first` mode
    (set at `StartApp`) where the Library hydrates from the store on launch and
    create/update/delete persist locally with **no HTTP**; creates are now
    **client-ulid-canonical** (temp-id dance retired for items — #818). The
    shared core keeps the web app online (`local_first = false`). **The iPhone
    Library is genuinely offline here.**
  - **B4 (folded into B3b).** Hardening done: a failed *local* write resolves
    `.failed` (not a phantom `.ack`), the core surfaces an error (#816) **and
    re-hydrates from the store to roll back the optimistic change** (#825) — a
    failed write event (`StoreWritten`) is kept separate from a read result
    (`StoreLoaded`) so a broken store can't loop reloading.
  - **B5** — decouple auth: the app runs with no account; sign-in is inert until
    sync exists.
  - **Gate:** full Library CRUD works in airplane mode, with no account.
- **Phase C (rethink + build the other pillars):** Practice, then Track, each on
  the local-first foundation. "Rethink as we build" lands here — a design pass
  (Pencil + HIG, reconsidering vs. web) *starts* each pillar, then local-first
  data, then per-screen quality (snapshot + accessibility) and iPad `SplitView`
  built *with* the screen. A redesign on a stable core, not a port.
  - **C-Practice (in progress):** the *session-history* surface shipped first —
    Practice home with seeded demo sessions (#902), the duration summary, the
    week calendar strip with day filtering (#905), and swipe paging between
    weeks (#911); plus an `IntradaSpacing`/`IntradaRadius` token system (#922).
    The **setlist builder** (the `SessionStatus::Building` flow — library-first
    builder with a reorderable queue tray) and the **active player + post-session
    summary** (player Slice 1, #964/#932) have since shipped, closing the
    build→practise→reflect→save loop. Next: per-item transition beats (Slice 2,
    #961) and the SaveSession optimistic-clear retry path (#974).
- **Phase D (sync = the paid tier):** LWW sync to the Axum API (server-
  authoritative `updated_at`, tombstones, deterministic tiebreak — designed
  above); account/sign-in gates sync; StoreKit subscription + entitlement
  gating; backup/restore. The parked #800 error-surface folds in here. Retire
  the Tauri host at parity.

## Quality baked in (day one, not retrofit)

- **swift-snapshot-testing** (pointfreeco, 1.19.x) — the automated agent's
  "eyes" for UI regression. Pin one CI simulator + iOS runtime; use perceptual
  tolerance; reference images are reviewable diffs.
- **Sentry** crash reporting from the first build.
- **Accessibility** per screen — VoiceOver labels + Dynamic Type — verified as
  each screen lands, not at the end.

## Open questions

- ~~**Existing server data on first local-first launch**~~ — **settled
  2026-06-01: seed empty.** No users to migrate, so no one-time import is
  built; "getting your data onto a device" is just the Phase D sync pull (auth-
  gated), so we write zero throwaway import code.
- **Free-tier auth shape** — fully account-free vs. an anonymous local account
  (eases later linking to a sync subscription). Decided before B5.
- **Android timing**: resolved. A second native shell on the same core is
  specced in `specs/android-shell.md` (#1774); the build starts after v0.13.
- **Web data model** — deferred; web shell stays online-only for now.
- **Sync transport detail** (full-table vs delta, batching) — designed in Phase D.

## Decisions log

- 2026-05-31 — App-first, local-first, LWW-not-CRDT. (Reverses #382.)
- 2026-05-31 — Build pipeline: spike cargo-swift first, build-ios.sh fallback.
- 2026-05-31 — Persistence is a custom `Effect`/`Command`, not a Capability
  (Capability API removed in Crux 0.17).
- 2026-05-31 — SQLite owned by the Swift shell (GRDB); reconciliation in core.
- 2026-05-31 — Mitigate UniFFI #2818 in the build recipe (non-MainActor /
  `nonisolated` post-process).
- 2026-06-01 — **Offline-first is the product model**, not just an
  implementation detail: the app is fully functional with no network and no
  account. (Strengthens the 2026-05-31 local-first decision.)
- 2026-06-01 — **Sync is the paid tier.** Free = single-device offline; paid
  subscription = multi-device sync + backup/restore. Backend = sync/backup
  service. Auth is optional (only gates sync).
- 2026-06-01 — **Rethink as we build:** native is not a web port; each pillar
  gets a design pass before implementation.
- 2026-06-01 — **#800 parked** (online-mutation error banner + rollback) — wrong
  model for offline-first; the error-surface folds into Phase D sync.
- 2026-06-01 — **Phase B (local-first persistence) promoted to the active
  critical path**, retrofitting under the already-built online Library screens.
- 2026-06-01 — **Sync engine deferred; local store built sync-agnostic**
  (verified deep-research). Turso offline-sync ruled out for the paid tier
  while beta/lossy; roll-our-own LWW-to-Turso is the lead, Automerge-in-the-core
  the fallback. B2 schema bakes in `updated_at` + tombstones so the choice
  stays open.

## YAGNI (explicitly out of scope for now)

Xcode Cloud, fastlane match, localization. The Android shell has its own spec,
`specs/android-shell.md`.
