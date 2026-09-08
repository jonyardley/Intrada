---
paths:
  - "ios/**"
---

# The per-screen quality bar

Every screen ships with a snapshot test, VoiceOver labels, Dynamic Type and an
iPad `SplitView`, built with the screen rather than retrofitted. Sentry is
wired from the first build.

## Principles from the 2026-06 review

- **Surface, don't swallow, at every layer.** Every `ViewModel.error` has a UI
  surface. Optimistic UI reconciles with the core's confirmed outcome: never
  fire a success haptic or dismiss a sheet before the core confirms (re-read
  `viewModel.error` after `store.send`; see `LibraryAddScreen.add`).
- **A stated invariant is an enforced invariant.** Back each offline-first
  invariant with a test and a CI gate; prose plus an opt-in local hook is
  effectively off.
- **Sync-boundary discipline now.** Shell and core agree on the timestamp
  format, and merge policy lives in the core even before the sync engine
  exists. No merge rules in shell SQL.
- **Consolidate before you template.** Extract a shared primitive the moment a
  second screen would copy it. The Library screens are the template the other
  pillars clone.
- **Bridge-crossing types get a real round-trip test before a screen reads
  them.** Extend the Rust `assert_round_trips` helper to every new payload; a
  stub-bridge test cannot catch a bincode wire break (#846). `LiveBridge` in
  `StoreEffectLoopTests` is the real-bridge harness.

## Snapshot hygiene (`ios/IntradaTests/__Snapshots__`)

References are binaries committed to git, re-recorded on every intentional UI
change, and on the free tier they are the only UI quality gate. Keep the suite
lean:

- **One device and scale, deterministic host.** Pin `.iPhone13` and
  `displayScale`, force light mode at the controller, use the stub bridge.
  Snapshot a variant only when it can regress independently.
- **Snapshot load-bearing states, not the cross-product.** Prefer
  component-level (`sizeThatFits`) or structural snapshots where the assertion
  is not pixel-perfect.
- **Re-record with `just ios-snapshots-record <filter>`**, never by hand. It
  deletes the matching references, runs only those tests (recording is
  fail-then-pass by design), optimises what it wrote and re-checks hygiene. If
  you recorded another way, run `just ios-snapshots-optimize` before committing;
  CI's Snapshot Hygiene job fails on un-optimised references.
- **Over the size ceiling? Read `scripts/check-snapshots.sh` first.** Its
  allowlist holds references that stay large as lossless PNG (smooth gradients,
  dense-control screens). Cropping does not help those: the gradient is the
  whole bill. Add to the allowlist with the reason.
- **No orphans.** Delete a test, delete its PNG. CI's Snapshot Hygiene job
  fails any reference with no matching `func test…`; `just ios-snapshots-check`
  runs it locally.
