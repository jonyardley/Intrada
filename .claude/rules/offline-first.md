---
paths:
  - "crates/intrada-core/src/**"
  - "ios/Intrada/Core/**"
  - "ios/IntradaTests/LibraryStore*.swift"
---

# Offline-first invariants

On-device SQLite is the source of truth, the app works with no network and no
account, and sync is a future paid tier. On the free tier the device is the
only copy of the user's data. Break one of these and the app silently stops
being offline.

1. **No network on the local-first path.** New reads and writes go through the
   persistence `Effect`, and there is no network path.
2. **Every persisted entity is sync-ready from day one**: `updated_at` and a
   soft-delete `deleted_at` tombstone, no hard deletes. Test-enforced for the
   schema.
3. **Client-owned ids.** New entities mint their ulid locally as the canonical
   id.
4. **Reconciliation lives in the core.** Sync, LWW and merge logic is Rust; the
   shell executes typed storage ops.
5. **A failed local write is never a silent success.** Storage ops resolve
   `PersistenceOutput::Failed` and the core surfaces it; never fake an `Ack`
   (#816).
6. **A single write path.** There is one local-first path, not two branches to
   keep in sync.
7. **No account gate on core functionality.** Only sync may require auth.
8. **Relational data in GRDB; only small singletons in `crux_kv`** (settings,
   the crash-recovery blob).

## Local data migrations (GRDB, `LibraryStore`)

A destructive or buggy migration that ships is unrecoverable data loss.

- **Append-only, forward-only, ordered.** Add a new `registerMigration("vN_…")`;
  never edit or delete a shipped one. Users skip versions, so the chain must
  run cleanly from any past version.
- **Additive by default.** Nullable columns and new tables are safe. Drop,
  rename or retype through a copy-table migration, and prefer to defer
  destructive changes until backup exists.
- **Core type, schema and codec change together**: the Rust field (`Option` or
  `#[serde(default)]`), the migration with a default for existing rows, and the
  row-to-`Item` codec, in one change.
- **Test the upgrade path.** Every migration ships with a test that a database
  populated at the previous version migrates with data intact.

## PR checklist for persistence, sync or a new entity

- [ ] Reads and writes go through the persistence `Effect` (1)
- [ ] New table or columns carry `updated_at` and `deleted_at`; no hard delete (2)
- [ ] Client-minted ulid as the canonical id (3)
- [ ] Merge logic in the core (4)
- [ ] A failed local write resolves `Failed`, never `Ack` (5)
- [ ] Migration appended, additive where possible, with an upgrade-path test
