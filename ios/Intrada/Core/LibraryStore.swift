import Foundation
import GRDB
import SharedTypes

/// Persistence ops the Store resolves against — a protocol so tests can inject a failing fake (#816).
protocol ItemStore {
  func loadItems() throws -> [Item]
  func save(_ item: Item) throws
  /// Upsert a batch in one transaction — all rows land or none do (#1106).
  func save(_ items: [Item]) throws
  func delete(id: String, deletedAt: String) throws
  func loadSessions() throws -> [PracticeSession]
  func saveSession(_ session: PracticeSession) throws
}

/// On-device SQLite store (GRDB) — the B2 local-first persistence layer the
/// `Effect.persistence` operations resolve against. The schema is deliberately
/// **sync-agnostic**: every row carries `updated_at` + a soft-delete tombstone
/// so a later sync engine (custom LWW or Automerge) can sit on top without a
/// migration (see specs/native-ios.md "Sync engine").
///
/// Calls are synchronous; the dataset is single-user and tiny, so GRDB's own
/// serialization is enough and an off-main hop isn't worth the Sendable dance
/// against the non-Sendable generated `Item`. Revisit if data volume grows.
final class LibraryStore: ItemStore {
  private let dbQueue: DatabaseQueue

  init(_ dbQueue: DatabaseQueue) throws {
    self.dbQueue = dbQueue
    try Self.migrator.migrate(dbQueue)
  }

  /// File-backed store in Application Support (the real app).
  static func onDisk() throws -> LibraryStore {
    let dir = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    return try LibraryStore(DatabaseQueue(path: dir.appendingPathComponent("intrada.sqlite").path))
  }

  /// In-memory store for tests/previews.
  static func inMemory() throws -> LibraryStore {
    try LibraryStore(DatabaseQueue())
  }

  // ── Operations ───────────────────────────────────────────────────────

  func loadItems() throws -> [Item] {
    try dbQueue.read { db in
      // Variants load tombstones included: the core owns reconciliation
      // (resurrect-by-label) and history labels resolve through them (#1083).
      let variantsByItem = try Self.variantsByItem(db)
      return try Row.fetchAll(
        db, sql: "SELECT * FROM item WHERE deleted_at IS NULL ORDER BY created_at DESC"
      )
      .map { row in Self.item(from: row, variants: variantsByItem[row["id"]] ?? []) }
    }
  }

  /// Insert or update by id; clears any tombstone (an upsert revives a row).
  func save(_ item: Item) throws {
    try dbQueue.write { db in
      try Self.upsert(item, in: db)
    }
  }

  /// Batch upsert in a single transaction — the chart-to-scaffold commit writes
  /// N exercises + the piece all-or-nothing, so a mid-batch failure never
  /// orphans exercises against a half-linked piece (#1106, invariant 5).
  func save(_ items: [Item]) throws {
    try dbQueue.write { db in
      for item in items {
        try Self.upsert(item, in: db)
      }
    }
  }

  private static func upsert(_ item: Item, in db: Database) throws {
    try db.execute(
      sql: """
        INSERT INTO item
          (id, title, kind, composer, key, modality, tempo_marking, tempo_bpm, notes, tags,
           linked_exercise_ids, created_at, updated_at, priority, chord_chart, photo_id,
           metre, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title, kind = excluded.kind, composer = excluded.composer,
          key = excluded.key, modality = excluded.modality,
          tempo_marking = excluded.tempo_marking,
          tempo_bpm = excluded.tempo_bpm, notes = excluded.notes, tags = excluded.tags,
          linked_exercise_ids = excluded.linked_exercise_ids,
          updated_at = excluded.updated_at, priority = excluded.priority,
          chord_chart = excluded.chord_chart, photo_id = excluded.photo_id,
          metre = excluded.metre, deleted_at = NULL
        """,
      arguments: [
        item.id, item.title, Self.kindString(item.kind), item.composer, item.key,
        Self.modalityString(item.modality),
        item.tempo?.marking, item.tempo?.bpm.map { Int($0) }, item.notes,
        Self.encodeTags(item.tags),
        Self.encodeLinkedExerciseIds(item.linkedExerciseIds),
        item.createdAt, item.updatedAt, item.priority,
        Self.encodeChordChart(item.chordChart), item.photoId, Self.encodeMetre(item.metre),
      ])
    // Same transaction as the item row, keyed by id; no delete-missing: the
    // core always carries the tombstones it loaded and writes them back
    // verbatim, so Swift never diffs and a tombstone round-trips (fixes the
    // forced-NULL resurrect hazard, #1113).
    for v in item.variants {
      try db.execute(
        sql: """
          INSERT INTO variant (id, item_id, label, position, updated_at, deleted_at)
          VALUES (?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            item_id = excluded.item_id, label = excluded.label,
            position = excluded.position, updated_at = excluded.updated_at,
            deleted_at = excluded.deleted_at
          """,
        arguments: [v.id, item.id, v.label, Int(v.position), v.updatedAt, v.deletedAt])
    }
  }

  /// Soft-delete: write the core-stamped `deletedAt` tombstone (RFC3339, same
  /// format as `updated_at`) rather than removing the row, so the deletion can
  /// win a later last-write-wins sync.
  func delete(id: String, deletedAt: String) throws {
    try dbQueue.write { db in
      try db.execute(
        sql: "UPDATE item SET deleted_at = ? WHERE id = ?",
        arguments: [deletedAt, id])
    }
  }

  func loadSessions() throws -> [PracticeSession] {
    try dbQueue.read { db in
      try Row.fetchAll(
        db, sql: "SELECT * FROM session WHERE deleted_at IS NULL ORDER BY completed_at DESC"
      )
      .map(Self.session(from:))
    }
  }

  /// Insert or update by id. A session is immutable once completed, so
  /// `updated_at` simply tracks `completed_at` — the column exists for sync LWW.
  func saveSession(_ session: PracticeSession) throws {
    try dbQueue.write { db in
      try db.execute(
        sql: """
          INSERT INTO session
            (id, started_at, completed_at, total_duration_secs, completion_status,
             session_notes, session_intention, entries, updated_at, deleted_at, session_score,
             reflection_improved, reflection_still_rough, reflection_next_target)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            started_at = excluded.started_at, completed_at = excluded.completed_at,
            total_duration_secs = excluded.total_duration_secs,
            completion_status = excluded.completion_status,
            session_notes = excluded.session_notes, session_intention = excluded.session_intention,
            entries = excluded.entries, updated_at = excluded.updated_at, deleted_at = NULL,
            session_score = excluded.session_score,
            reflection_improved = excluded.reflection_improved,
            reflection_still_rough = excluded.reflection_still_rough,
            reflection_next_target = excluded.reflection_next_target
          """,
        arguments: [
          session.id, session.startedAt, session.completedAt,
          Int(session.totalDurationSecs), Self.completionString(session.completionStatus),
          session.sessionNotes, session.sessionIntention,
          Self.encodeEntries(session.entries), session.completedAt,
          session.sessionScore.map { Int($0) },
          session.reflectionImproved, session.reflectionStillRough,
          session.reflectionNextTarget,
        ])
    }
  }

  /// Column names of a table (for the schema-invariant test). `[String]` not
  /// `Set` — `SharedTypes`' domain `Set` shadows `Swift.Set` here.
  func columnNames(ofTable table: String) throws -> [String] {
    try dbQueue.read { db in try db.columns(in: table).map(\.name) }
  }

  // ── Schema ───────────────────────────────────────────────────────────

  static let migrator: DatabaseMigrator = {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1_item") { db in
      try db.execute(
        sql: """
          CREATE TABLE item (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            kind TEXT NOT NULL,
            composer TEXT,
            key TEXT,
            tempo_marking TEXT,
            tempo_bpm INTEGER,
            notes TEXT,
            tags TEXT NOT NULL DEFAULT '[]',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            priority INTEGER NOT NULL DEFAULT 0,
            deleted_at TEXT
          )
          """)
    }
    migrator.registerMigration("v2_add_modality") { db in
      try db.execute(sql: "ALTER TABLE item ADD COLUMN modality TEXT")
    }
    migrator.registerMigration("v3_session") { db in
      try db.execute(
        sql: """
          CREATE TABLE session (
            id TEXT PRIMARY KEY NOT NULL,
            started_at TEXT NOT NULL,
            completed_at TEXT NOT NULL,
            total_duration_secs INTEGER NOT NULL,
            completion_status TEXT NOT NULL,
            session_notes TEXT,
            session_intention TEXT,
            entries TEXT NOT NULL DEFAULT '[]',
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
          """)
    }
    migrator.registerMigration("v4_session_score") { db in
      try db.execute(sql: "ALTER TABLE session ADD COLUMN session_score INTEGER")
    }
    migrator.registerMigration("v5_rescale_entry_scores") { db in
      let rows = try Row.fetchAll(db, sql: "SELECT id, entries FROM session")
      for row in rows {
        let id: String = row["id"]
        let json: String = row["entries"]
        guard var dtos = try? JSONDecoder().decode([StoredEntry].self, from: Data(json.utf8))
        else { continue }
        for i in dtos.indices {
          if let s = dtos[i].score { dtos[i].score = UInt8(min(10, Int(s) * 2)) }
        }
        guard let data = try? JSONEncoder().encode(dtos),
          let rescaled = String(data: data, encoding: .utf8)
        else { continue }
        try db.execute(
          sql: "UPDATE session SET entries = ? WHERE id = ?", arguments: [rescaled, id])
      }
    }
    migrator.registerMigration("v6_item_linked_exercises") { db in
      try db.execute(
        sql: "ALTER TABLE item ADD COLUMN linked_exercise_ids TEXT NOT NULL DEFAULT '[]'")
    }
    migrator.registerMigration("v7_session_reflections") { db in
      try db.execute(sql: "ALTER TABLE session ADD COLUMN reflection_improved TEXT")
      try db.execute(sql: "ALTER TABLE session ADD COLUMN reflection_still_rough TEXT")
      try db.execute(sql: "ALTER TABLE session ADD COLUMN reflection_next_target TEXT")
    }
    migrator.registerMigration("v8_item_chord_chart") { db in
      // Nullable JSON column; NULL = no chart. Additive, non-destructive.
      try db.execute(sql: "ALTER TABLE item ADD COLUMN chord_chart TEXT")
    }
    migrator.registerMigration("v9_variant") { db in
      // Exercise variation ladders (#1083). First normalized child table: per-row
      // `updated_at`/`deleted_at` give the future sync engine per-variation LWW +
      // tombstones (invariant 2) that a JSON blob on `item` couldn't. Additive —
      // existing exercises simply have no rows here (an empty ladder).
      try db.execute(
        sql: """
          CREATE TABLE variant (
            id TEXT PRIMARY KEY NOT NULL,
            item_id TEXT NOT NULL,
            label TEXT NOT NULL,
            position INTEGER NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
          """)
      try db.execute(sql: "CREATE INDEX index_variant_on_item_id ON variant(item_id)")
    }
    migrator.registerMigration("v10_coach_records") { db in
      // Drill-loop evidence (#1181, spec §4), written as each record closes.
      // `attempts` is a JSON blob for the same reason `session.entries` is.
      try db.execute(
        sql: """
          CREATE TABLE block_record (
            id TEXT PRIMARY KEY NOT NULL,
            node TEXT NOT NULL,
            drill TEXT NOT NULL,
            gate TEXT NOT NULL,
            level_tempo_bpm INTEGER NOT NULL,
            level_click_level TEXT NOT NULL,
            circle TEXT NOT NULL,
            mode TEXT NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT NOT NULL,
            attempts TEXT NOT NULL DEFAULT '[]',
            attempts_to_pass INTEGER,
            gate_opened_at_attempt INTEGER,
            reps_after_gate INTEGER NOT NULL,
            active_ms INTEGER NOT NULL,
            escalation_fired TEXT NOT NULL DEFAULT '[]',
            exit TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
          """)
      try db.execute(
        sql: """
          CREATE TABLE wander_record (
            id TEXT PRIMARY KEY NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT NOT NULL,
            attempts TEXT NOT NULL DEFAULT '[]',
            keep_as_drill INTEGER,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
          """)
    }
    migrator.registerMigration("v11_built_session") { db in
      // Self-directed practice (#1256, coach era, removed #1344 — table kept
      // as a dead migration per the append-only rule). `blocks` and
      // `sections` are JSON blobs for the same reason `session.entries` is:
      // ordered child docs edited as one document, not independently synced rows.
      try db.execute(
        sql: """
          CREATE TABLE user_drill (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            criterion TEXT NOT NULL,
            tempo_bpm INTEGER,
            keys TEXT NOT NULL DEFAULT '[]',
            passes_to_open INTEGER NOT NULL,
            serves_kind TEXT,
            serves_value TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
          """)
      try db.execute(
        sql: """
          CREATE TABLE journal_item (
            id TEXT PRIMARY KEY NOT NULL,
            name TEXT NOT NULL,
            notes TEXT,
            linked_item_id TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
          """)
      try db.execute(
        sql: """
          CREATE TABLE built_session (
            id TEXT PRIMARY KEY NOT NULL,
            source TEXT,
            blocks TEXT NOT NULL DEFAULT '[]',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
          """)
      try db.execute(
        sql: """
          CREATE TABLE play_through (
            id TEXT PRIMARY KEY NOT NULL,
            item_id TEXT NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT NOT NULL,
            counted INTEGER NOT NULL,
            sections TEXT NOT NULL DEFAULT '[]',
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
          """)
      try db.execute(
        sql: """
          CREATE TABLE reflection (
            id TEXT PRIMARY KEY NOT NULL,
            kind TEXT NOT NULL,
            session_ref TEXT,
            transcript TEXT,
            audio_path TEXT,
            duration_s INTEGER,
            at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
          """)
      try db.execute(
        sql: """
          CREATE TABLE feel_entry (
            id TEXT PRIMARY KEY NOT NULL,
            block_id TEXT NOT NULL,
            feel TEXT NOT NULL,
            at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
          """)
    }
    migrator.registerMigration("v12_block_origin") { db in
      // #1256: whose block this was. A record written before built sessions
      // existed can only have been the planner's, so 'authored' is the honest
      // backfill — and it is what the mastery rebuild reads to decide whether a
      // block's taps were ever evidence (decision 17).
      try db.execute(
        sql: "ALTER TABLE block_record ADD COLUMN origin TEXT NOT NULL DEFAULT 'authored'")
    }
    migrator.registerMigration("v13_wander_item") { db in
      // #1256 Phase C: off-piste is now reachable from a piece (B0), so a
      // wander can name what it was played against. Nullable, because the
      // mid-session door has no piece behind it and every existing row came
      // through it.
      try db.execute(sql: "ALTER TABLE wander_record ADD COLUMN item_id TEXT")
    }
    migrator.registerMigration("v14_unmonitored_play") { db in
      // #1285: its own table rather than a discriminated `wander_record`,
      // because a table with no column for a piece cannot be made to name one —
      // decision 7's "minutes only", enforced by the schema rather than stated.
      try db.execute(
        sql: """
          CREATE TABLE unmonitored_play (
            id TEXT PRIMARY KEY NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
          """)
    }
    migrator.registerMigration("v15_reflection_steer") { db in
      // #1256 Phase D: what became of the morning proposal a reflection earned
      // (C3). 'unoffered' is the honest backfill — a reflection written before
      // the card existed was never offered one — and it is also what stops a
      // reflection from last month arriving as this morning's steer on upgrade.
      try db.execute(
        sql: "ALTER TABLE reflection ADD COLUMN steer TEXT NOT NULL DEFAULT 'unoffered'")
      try db.execute(sql: "ALTER TABLE reflection ADD COLUMN steer_at TEXT")
    }
    migrator.registerMigration("v16_item_photo") { db in
      // Id only: a BLOB would fatten every row of a table `loadItems` reads
      // whole (specs/piece-from-photo.md, key decision 1).
      try db.execute(sql: "ALTER TABLE item ADD COLUMN photo_id TEXT")
    }
    migrator.registerMigration("v17_item_metre") { db in
      try db.execute(sql: "ALTER TABLE item ADD COLUMN metre TEXT")
      // The chart carried beats-per-bar alone; a charted piece keeps that as a
      // crotchet-unit metre. The chart's own copy stays in the JSON, ignored:
      // ignoring is cheaper and safer than a copy-table drop (CLAUDE.md,
      // local data migrations).
      try db.execute(
        sql: """
          UPDATE item
          SET metre = json_object('beats', json_extract(chord_chart, '$.metre'), 'unit', 4)
          WHERE chord_chart IS NOT NULL AND json_extract(chord_chart, '$.metre') IS NOT NULL
          """)
    }
    return migrator
  }()

  // ── Row ↔ Item codec ─────────────────────────────────────────────────

  // Surface (don't silently default) a stored enum string we don't recognise —
  // e.g. an older binary reading a row a newer version wrote (#949).
  private static let decodeContext = "LibraryStore decode"

  private struct UnknownStoredEnum: Error, CustomStringConvertible {
    let kind: String
    let raw: String
    var description: String { "unknown \(kind) on decode: \"\(raw)\"" }
  }

  private static func item(from row: Row, variants: [Variant]) -> Item {
    let marking: String? = row["tempo_marking"]
    let bpm: UInt16? = (row["tempo_bpm"] as Int?).map { UInt16($0) }
    let tempo = (marking == nil && bpm == nil) ? nil : Tempo(marking: marking, bpm: bpm)
    return Item(
      id: row["id"], title: row["title"], kind: kind(from: row["kind"]),
      composer: row["composer"], key: row["key"], modality: modality(from: row["modality"]),
      tempo: tempo, notes: row["notes"],
      tags: decodeTags(row["tags"]),
      linkedExerciseIds: decodeLinkedExerciseIds(row["linked_exercise_ids"]),
      createdAt: row["created_at"], updatedAt: row["updated_at"],
      priority: row["priority"],
      chordChart: decodeChordChart(row["chord_chart"]),
      variants: variants,
      photoId: row["photo_id"], metre: decodeMetre(row["metre"]))
  }

  // ── Metre codec ──────────────────────────────────────────────────────

  private struct StoredMetre: Codable {
    var beats: UInt8
    var unit: UInt8
    var groups: [UInt8]?
  }

  private static func encodeMetre(_ metre: Metre?) -> String? {
    guard let metre else { return nil }
    let dto = StoredMetre(beats: metre.beats, unit: metre.unit, groups: metre.groups)
    guard let data = try? JSONEncoder().encode(dto) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func decodeMetre(_ json: String?) -> Metre? {
    guard let json,
      let dto = try? JSONDecoder().decode(StoredMetre.self, from: Data(json.utf8))
    else { return nil }
    return Metre(beats: dto.beats, unit: dto.unit, groups: dto.groups)
  }

  // ── Row ↔ Variant codec ──────────────────────────────────────────────

  private static func variant(from row: Row) -> Variant {
    Variant(
      id: row["id"], label: row["label"], position: UInt64(row["position"] as Int),
      updatedAt: row["updated_at"], deletedAt: row["deleted_at"])
  }

  /// All variants (variations) grouped by owning item, in ladder order, tombstones
  /// included, per the core's reconciliation contract (#1083). One query for
  /// the whole library, keyed by `item_id`, so `loadItems` stays O(1) reads.
  private static func variantsByItem(_ db: Database) throws -> [String: [Variant]] {
    let rows = try Row.fetchAll(
      db,
      sql: "SELECT * FROM variant ORDER BY item_id, position, id")
    var byItem: [String: [Variant]] = [:]
    for row in rows {
      byItem[row["item_id"], default: []].append(variant(from: row))
    }
    return byItem
  }

  private static func kindString(_ kind: ItemKind) -> String {
    switch kind {
    case .piece: "piece"
    case .exercise: "exercise"
    }
  }

  private static func modalityString(_ modality: Modality?) -> String? {
    switch modality {
    case .major: "major"
    case .minor: "minor"
    case nil: nil
    }
  }

  private static func modality(from raw: String?) -> Modality? {
    switch raw {
    case "major": return .major
    case "minor": return .minor
    case nil: return nil
    case .some(let other):
      report(UnknownStoredEnum(kind: "Modality", raw: other), decodeContext)
      return nil
    }
  }

  private static func kind(from raw: String) -> ItemKind {
    switch raw {
    case "piece": return .piece
    case "exercise": return .exercise
    default:
      report(UnknownStoredEnum(kind: "ItemKind", raw: raw), decodeContext)
      return .piece
    }
  }

  private static func encodeTags(_ tags: [String]) -> String {
    guard let data = try? JSONEncoder().encode(tags), let json = String(data: data, encoding: .utf8)
    else { return "[]" }
    return json
  }

  private static func decodeTags(_ json: String) -> [String] {
    (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
  }

  private static func encodeLinkedExerciseIds(_ ids: [String]) -> String {
    guard let data = try? JSONEncoder().encode(ids), let json = String(data: data, encoding: .utf8)
    else { return "[]" }
    return json
  }

  private static func decodeLinkedExerciseIds(_ json: String) -> [String] {
    (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
  }

  // ── Row ↔ ChordChart codec ───────────────────────────────────────────
  // A nested aggregate, so JSON via a Codable DTO (like StoredEntry) — never
  // bincode: positional encoding would fail to decode old rows after a field
  // change, and the device is the only copy.

  private struct StoredChart: Codable {
    var key: String
    var modality: String
    // Pre-v17 rows carry the beats here; the item's `metre` column owns it now.
    var metre: UInt8?
    var sections: [StoredSection]
  }
  private struct StoredSection: Codable {
    var label: String?
    var bars: [StoredBar]
  }
  private struct StoredBar: Codable {
    var chords: [StoredChartChord]
  }
  private struct StoredChartChord: Codable {
    var symbol: StoredChordSymbol
    var beats: UInt8
  }
  private struct StoredChordSymbol: Codable {
    var root: UInt8
    var quality: String
    var extensions: [String]
    var bass: UInt8?
    var raw: String
  }

  private struct ChartCodecError: Error, CustomStringConvertible {
    let phase: String
    var description: String { "chord chart failed to \(phase)" }
  }

  private static func encodeChordChart(_ chart: ChordChart?) -> String? {
    guard let chart else { return nil }
    let dto = StoredChart(
      key: chart.key, modality: modalityString(chart.modality) ?? "major", metre: nil,
      sections: chart.sections.map { section in
        StoredSection(
          label: section.label,
          bars: section.bars.map { bar in
            StoredBar(
              chords: bar.chords.map { chord in
                StoredChartChord(
                  symbol: StoredChordSymbol(
                    root: chord.symbol.root, quality: chordQualityString(chord.symbol.quality),
                    extensions: chord.symbol.extensions, bass: chord.symbol.bass,
                    raw: chord.symbol.raw),
                  beats: chord.beats)
              })
          })
      })
    guard let data = try? JSONEncoder().encode(dto), let json = String(data: data, encoding: .utf8)
    else {
      // Surface, don't swallow: a chart that fails to encode would otherwise be
      // stored as NULL (silently "no chart") on the only copy of the data.
      report(ChartCodecError(phase: "encode"), decodeContext)
      return nil
    }
    return json
  }

  private static func decodeChordChart(_ json: String?) -> ChordChart? {
    guard let json else { return nil }  // no chart — legitimate
    guard let dto = try? JSONDecoder().decode(StoredChart.self, from: Data(json.utf8)) else {
      report(ChartCodecError(phase: "decode"), decodeContext)
      return nil
    }
    return ChordChart(
      key: dto.key, modality: modality(from: dto.modality) ?? .major,
      sections: dto.sections.map { section in
        ChartSection(
          label: section.label,
          bars: section.bars.map { bar in
            Bar(
              chords: bar.chords.map { chord in
                ChartChord(
                  symbol: ChordSymbol(
                    root: chord.symbol.root,
                    quality: chordQuality(from: chord.symbol.quality),
                    extensions: chord.symbol.extensions, bass: chord.symbol.bass,
                    raw: chord.symbol.raw),
                  beats: chord.beats)
              })
          })
      })
  }

  private static func chordQualityString(_ q: ChordQuality) -> String {
    switch q {
    case .maj7: "maj7"
    case .dom7: "dom7"
    case .min7: "min7"
    case .min7b5: "min7b5"
    case .dim7: "dim7"
    case .minMaj7: "minMaj7"
    case .six: "six"
    case .min6: "min6"
    case .alt: "alt"
    case .sus4: "sus4"
    case .sus2: "sus2"
    case .aug: "aug"
    case .dom7Sharp5: "dom7Sharp5"
    case .other: "other"
    }
  }

  private static func chordQuality(from raw: String) -> ChordQuality {
    switch raw {
    case "maj7": return .maj7
    case "dom7": return .dom7
    case "min7": return .min7
    case "min7b5": return .min7b5
    case "dim7": return .dim7
    case "minMaj7": return .minMaj7
    case "six": return .six
    case "min6": return .min6
    case "alt": return .alt
    case "sus4": return .sus4
    case "sus2": return .sus2
    case "aug": return .aug
    case "dom7Sharp5": return .dom7Sharp5
    case "other": return .other
    default:
      report(UnknownStoredEnum(kind: "ChordQuality", raw: raw), decodeContext)
      return .other  // conservative: an unknown quality falls back to arpeggio
    }
  }

  // ── Row ↔ PracticeSession codec ──────────────────────────────────────

  private static func session(from row: Row) -> PracticeSession {
    let score: Int64? = row["session_score"]
    return PracticeSession(
      id: row["id"], entries: decodeEntries(row["entries"], sessionStartedAt: row["started_at"]),
      sessionNotes: row["session_notes"], sessionIntention: row["session_intention"],
      startedAt: row["started_at"], completedAt: row["completed_at"],
      totalDurationSecs: UInt64(row["total_duration_secs"] as Int64),
      completionStatus: completionStatus(from: row["completion_status"]),
      sessionScore: score.map { UInt8(clamping: $0) },
      reflectionImproved: row["reflection_improved"],
      reflectionStillRough: row["reflection_still_rough"],
      reflectionNextTarget: row["reflection_next_target"])
  }

  // Entries (a nested, optional-heavy aggregate) go to JSON via a Codable DTO,
  // not bincode: bincode is positional, so a future field change would fail to
  // decode old rows — unacceptable when the device is the only copy.
  /// The per-play fields below `plannedDurationSecs` are LEGACY: every row
  /// written before #1739 carries them at entry level and has no `plays`, and
  /// `decodeEntries` folds them into one play. Nothing writes them any more,
  /// and nothing on device is rewritten (#1739 decision 8). The v5 migration
  /// still reads `score`, which is why it stays.
  private struct StoredEntry: Codable {
    var id: String
    var itemId: String
    var itemTitle: String
    var itemType: String
    var position: UInt64
    var durationSecs: UInt64
    var status: String
    var notes: String?
    var intention: String?
    var plannedDurationSecs: UInt32?
    var groupId: String?
    var plannedVariationId: String?
    var plannedRepTarget: UInt8?
    var plays: [StoredPlay]?

    var score: UInt8?
    var repTarget: UInt8?
    var repCount: UInt8?
    var repTargetReached: Bool?
    var repHistory: [StoredRepEvent]?
    var achievedTempo: UInt16?
    var variantId: String?
    var clickPattern: StoredClickState?
  }

  private struct StoredPlay: Codable {
    var id: String
    var variationId: String?
    var startedAt: String
    var seconds: UInt64
    var repTarget: UInt8?
    var repCount: UInt8?
    var repTargetReached: Bool?
    var repHistory: [StoredRepEvent]?
    var achievedTempo: UInt16?
    var clickPattern: StoredClickState?
    var score: UInt8?
  }

  private struct StoredClickState: Codable {
    var metre: StoredMetre
    var sounding: UInt16
  }

  private static func storedClick(_ state: ClickState?) -> StoredClickState? {
    state.map {
      StoredClickState(
        metre: StoredMetre(beats: $0.metre.beats, unit: $0.metre.unit, groups: $0.metre.groups),
        sounding: $0.sounding)
    }
  }

  private static func clickState(_ stored: StoredClickState?) -> ClickState? {
    stored.map {
      ClickState(
        metre: Metre(beats: $0.metre.beats, unit: $0.metre.unit, groups: $0.metre.groups),
        sounding: $0.sounding)
    }
  }

  /// Rows written before the history was timestamped hold bare action strings;
  /// those decode with no `at`, and the session start stands in for it.
  private struct StoredRepEvent: Codable {
    var action: String
    var at: String?

    init(action: String, at: String?) {
      self.action = action
      self.at = at
    }

    init(from decoder: Decoder) throws {
      if let legacy = try? decoder.singleValueContainer().decode(String.self) {
        action = legacy
        at = nil
        return
      }
      let keyed = try decoder.container(keyedBy: CodingKeys.self)
      action = try keyed.decode(String.self, forKey: .action)
      at = try keyed.decodeIfPresent(String.self, forKey: .at)
    }
  }

  private static func storedPlay(_ p: VariationPlay) -> StoredPlay {
    StoredPlay(
      id: p.id, variationId: p.variationId, startedAt: p.startedAt, seconds: p.seconds,
      repTarget: p.repTarget, repCount: p.repCount, repTargetReached: p.repTargetReached,
      repHistory: p.repHistory.map {
        $0.map { StoredRepEvent(action: repActionString($0.action), at: $0.at) }
      },
      achievedTempo: p.achievedTempo, clickPattern: storedClick(p.clickPattern), score: p.score)
  }

  private static func encodeEntries(_ entries: [SetlistEntry]) -> String {
    let dtos = entries.map { e in
      StoredEntry(
        id: e.id, itemId: e.itemId, itemTitle: e.itemTitle, itemType: kindString(e.itemType),
        position: e.position, durationSecs: e.durationSecs, status: entryStatusString(e.status),
        notes: e.notes, intention: e.intention, plannedDurationSecs: e.plannedDurationSecs,
        groupId: e.groupId, plannedVariationId: e.plannedVariationId,
        plannedRepTarget: e.plannedRepTarget, plays: e.plays.map(storedPlay))
    }
    guard let data = try? JSONEncoder().encode(dtos), let json = String(data: data, encoding: .utf8)
    else { return "[]" }
    return json
  }

  /// A row written before #1739 has no `plays` and carries one score, one rep
  /// count and one tempo on the entry itself. It folds into a single play so
  /// the record survives; nothing on device is rewritten (#1739 decision 8).
  /// An entry that was skipped or never reached keeps no play, which is what a
  /// zero-play entry means.
  private static func plays(from d: StoredEntry, sessionStartedAt: String) -> [VariationPlay] {
    if let stored = d.plays, !stored.isEmpty {
      return stored.map { p in
        VariationPlay(
          id: p.id, variationId: p.variationId, startedAt: p.startedAt, seconds: p.seconds,
          repTarget: p.repTarget, repCount: p.repCount, repTargetReached: p.repTargetReached,
          repHistory: p.repHistory.map {
            $0.map { RepEvent(action: repAction(from: $0.action), at: $0.at ?? sessionStartedAt) }
          },
          achievedTempo: p.achievedTempo, clickPattern: clickState(p.clickPattern), score: p.score)
      }
    }

    // A mark or a banked repetition is a record of practice whatever the status
    // says: rows written before #1739 froze rep state on a skip, and the core
    // still keeps that play, so the fold must not lose it on the way in.
    let recorded = d.score != nil || (d.repCount ?? 0) > 0
    guard entryStatus(from: d.status) == .completed || recorded else { return [] }

    return [
      VariationPlay(
        id: "\(d.id)-play", variationId: d.variantId, startedAt: sessionStartedAt,
        seconds: d.durationSecs, repTarget: d.repTarget, repCount: d.repCount,
        repTargetReached: d.repTargetReached,
        repHistory: d.repHistory.map {
          $0.map { RepEvent(action: repAction(from: $0.action), at: $0.at ?? sessionStartedAt) }
        },
        achievedTempo: d.achievedTempo, clickPattern: clickState(d.clickPattern), score: d.score)
    ]
  }

  private static func decodeEntries(_ json: String, sessionStartedAt: String) -> [SetlistEntry] {
    guard let dtos = try? JSONDecoder().decode([StoredEntry].self, from: Data(json.utf8)) else {
      return []
    }
    return dtos.map { d in
      SetlistEntry(
        id: d.id, itemId: d.itemId, itemTitle: d.itemTitle, itemType: kind(from: d.itemType),
        position: d.position, durationSecs: d.durationSecs, status: entryStatus(from: d.status),
        notes: d.notes, intention: d.intention, plannedDurationSecs: d.plannedDurationSecs,
        groupId: d.groupId, plannedVariationId: d.plannedVariationId ?? d.variantId,
        plannedRepTarget: d.plannedRepTarget ?? d.repTarget,
        plays: plays(from: d, sessionStartedAt: sessionStartedAt))
    }
  }

  private static func completionString(_ status: CompletionStatus) -> String {
    switch status {
    case .completed: "completed"
    case .endedEarly: "ended_early"
    }
  }

  private static func completionStatus(from raw: String) -> CompletionStatus {
    switch raw {
    case "completed": return .completed
    case "ended_early": return .endedEarly
    default:
      report(UnknownStoredEnum(kind: "CompletionStatus", raw: raw), decodeContext)
      return .completed
    }
  }

  private static func entryStatusString(_ status: EntryStatus) -> String {
    switch status {
    case .completed: "completed"
    case .skipped: "skipped"
    case .notAttempted: "not_attempted"
    }
  }

  private static func entryStatus(from raw: String) -> EntryStatus {
    switch raw {
    case "completed": return .completed
    case "skipped": return .skipped
    case "not_attempted": return .notAttempted
    default:
      report(UnknownStoredEnum(kind: "EntryStatus", raw: raw), decodeContext)
      return .notAttempted  // conservative: an unknown status must not inflate stats (#949)
    }
  }

  private static func repActionString(_ action: RepAction) -> String {
    switch action {
    case .missed: "missed"
    case .success: "success"
    }
  }

  private static func repAction(from raw: String) -> RepAction {
    switch raw {
    case "missed": return .missed
    case "success": return .success
    default:
      report(UnknownStoredEnum(kind: "RepAction", raw: raw), decodeContext)
      return .missed  // conservative: an unknown rep must not inflate achievement (#949)
    }
  }

}

#if DEBUG
  extension LibraryStore {
    /// Test seam for upgrade-path tests (CLAUDE.md "Local data migrations"):
    /// migrate to `version`, seed raw rows at that schema, then finish to HEAD.
    static func upgradeTestStore(migratedTo version: String, seed: String) throws -> LibraryStore {
      let queue = try DatabaseQueue()
      try migrator.migrate(queue, upTo: version)
      try queue.write { db in try db.execute(sql: seed) }
      return try LibraryStore(queue)
    }
  }
#endif
