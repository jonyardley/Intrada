---
paths:
  - "crates/intrada-core/src/domain/session.rs"
  - "crates/intrada-ffi/**"
  - "ios/generated/**"
  - "ios/Intrada/Core/LibraryStore.swift"
---

# You are on a silent-failure surface

A wrong change here does not crash. It decodes into a plausible wrong value,
drops a write, or destroys the only copy of a user's data. Before editing:

1. **Be on the strongest rung.** Fable at `xhigh` for the bridge and auth,
   `max` for a migration or anything inside the `ActiveSession` blob graph.
   Check with `/model` and `/effort`, and switch before the first edit.
2. **Pair the `reviewer` agent on the core diff before the screens half
   starts**, not only at the end. It is pinned never weaker than the writer.
3. **Domain-sensitivity override.** This work goes up at least one tier in
   ceremony, and a change to a bridge shape, a migration or the blob graph
   ships as two PRs: core first, screens in the same working session, or the
   core PR waits (a merged core PR with no caller is shell-dead, #1348, #1374).

The hazards, by file:

- **Bridge types (`intrada-ffi`, anything crossing the bridge).** The wire is
  positional bincode with no "absent". `deserialize_with`, `serialize_with`
  and `skip_serializing_if` on a non-trailing field produce a silent no-op,
  not a crash (#846). Branch on `Deserializer::is_human_readable()` for
  JSON-only behaviour, and cover the type with a real-bridge round-trip
  (`LiveBridge` in `StoreEffectLoopTests`).
- **`ios/generated/`.** Never hand-edit. Fix the Rust type and regenerate.
  UniFFI output fails under Swift 6.2 `MainActor`-default isolation
  (uniffi-rs#2818); the build recipe keeps the package non-MainActor-defaulted.
- **`domain/session.rs`.** A new field anywhere in the `ActiveSession` graph
  invalidates every crash-recovery blob on every device (#1345).
  `active_session_blob_wire_is_pinned` fails on purpose: bump
  `Store.sessionInProgressKey` first, then re-pin. Never only re-pin.
- **`LibraryStore.swift`.** Append-only on the device, per
  `.claude/rules/offline-first.md`.
