import SharedTypes
import XCTest

@testable import Intrada

final class LibraryStoreTests: XCTestCase {
  private func makeStore() throws -> LibraryStore { try LibraryStore.inMemory() }

  private func item(
    _ id: String, title: String = "Etude", kind: ItemKind = .piece,
    createdAt: String = "2026-01-01T00:00:00Z"
  ) -> Item {
    Item(
      id: id, title: title, kind: kind, composer: "Chopin", key: "C", modality: .major,
      tempo: Tempo(marking: "Allegro", bpm: 132), notes: "evenness",
      tags: ["scale", "warmup"], linkedExerciseIds: [], createdAt: createdAt,
      updatedAt: createdAt, priority: true, chordChart: nil, variants: [], photoId: nil, metre: nil)
  }

  func testSaveThenLoadRoundTrips() throws {
    let store = try makeStore()
    try store.save(item("p1"))
    let loaded = try store.loadItems()
    XCTAssertEqual(loaded.count, 1)
    let got = try XCTUnwrap(loaded.first)
    XCTAssertEqual(got.id, "p1")
    XCTAssertEqual(got.kind, .piece)
    XCTAssertEqual(got.key, "C")
    XCTAssertEqual(got.modality, .major)
    XCTAssertEqual(got.tempo, Tempo(marking: "Allegro", bpm: 132))
    XCTAssertEqual(got.tags, ["scale", "warmup"])
    XCTAssertTrue(got.priority)
  }

  func testBatchSaveUpsertsEveryRow() throws {
    let store = try makeStore()
    try store.save([item("a", title: "One"), item("b", title: "Two"), item("c", title: "Three")])
    let loaded = try store.loadItems()
    XCTAssertEqual(Swift.Set(loaded.map(\.id)), ["a", "b", "c"], "all batch rows land")
  }

  func testExerciseKindAndNilTempoRoundTrip() throws {
    let store = try makeStore()
    var ex = item("e1", kind: .exercise)
    ex.tempo = nil
    ex.tags = []
    try store.save(ex)
    let got = try XCTUnwrap(try store.loadItems().first)
    XCTAssertEqual(got.kind, .exercise)
    XCTAssertNil(got.tempo)
    XCTAssertEqual(got.tags, [])
  }

  func testNilModalityRoundTrips() throws {
    let store = try makeStore()
    var it = item("p1")
    it.modality = nil
    try store.save(it)
    XCTAssertNil(try XCTUnwrap(try store.loadItems().first).modality)
  }

  /// Upgrade path: a v1 row survives the v2 `modality` migration intact.
  func testV1RowSurvivesModalityMigration() throws {
    let store = try LibraryStore.upgradeTestStore(
      migratedTo: "v1_item",
      seed: """
        INSERT INTO item
          (id, title, kind, composer, key, tempo_marking, tempo_bpm, notes, tags,
           created_at, updated_at, priority, deleted_at)
        VALUES ('p1', 'Legacy Etude', 'piece', 'Bach', 'C', 'Allegro', 120, 'phrasing',
                '["scale"]', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 0, NULL)
        """)
    let loaded = try store.loadItems()
    XCTAssertEqual(loaded.count, 1, "the pre-existing v1 row must survive the v2 migration")
    let got = try XCTUnwrap(loaded.first)
    XCTAssertEqual(got.id, "p1")
    XCTAssertEqual(got.title, "Legacy Etude")
    XCTAssertEqual(got.composer, "Bach")
    XCTAssertNil(got.modality, "v2 adds modality as NULL for pre-existing rows")
    XCTAssertEqual(got.tempo, Tempo(marking: "Allegro", bpm: 120))
    XCTAssertEqual(got.tags, ["scale"])
    XCTAssertFalse(got.priority)
  }

  func testUpsertUpdatesInPlace() throws {
    let store = try makeStore()
    try store.save(item("p1", title: "Before"))
    try store.save(item("p1", title: "After"))
    let loaded = try store.loadItems()
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.title, "After")
  }

  func testDeleteTombstonesAndHidesFromLoad() throws {
    let store = try makeStore()
    try store.save(item("p1"))
    try store.delete(id: "p1", deletedAt: "2026-01-02T00:00:00+00:00")
    XCTAssertTrue(try store.loadItems().isEmpty)
  }

  func testSaveRevivesADeletedRow() throws {
    let store = try makeStore()
    try store.save(item("p1"))
    try store.delete(id: "p1", deletedAt: "2026-01-02T00:00:00+00:00")
    try store.save(item("p1", title: "Revived"))
    let loaded = try store.loadItems()
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(loaded.first?.title, "Revived")
  }

  func testLoadOrdersNewestFirst() throws {
    let store = try makeStore()
    try store.save(item("old", title: "Old", createdAt: "2026-01-01T00:00:00Z"))
    try store.save(item("new", title: "New", createdAt: "2026-02-01T00:00:00Z"))
    XCTAssertEqual(try store.loadItems().map(\.id), ["new", "old"])
  }

  /// Offline-first invariant #2 (CLAUDE.md): persisted tables carry the sync columns.
  func testSchemaHasSyncColumns() throws {
    let columns = try makeStore().columnNames(ofTable: "item")
    XCTAssertTrue(
      columns.contains("updated_at"), "item table must carry updated_at; has \(columns)")
    XCTAssertTrue(
      columns.contains("deleted_at"), "item table must carry deleted_at; has \(columns)")
  }

  // ── Variants (#1083) ──────────────────────────────────────────────────

  private func variant(
    _ id: String, label: String, position: UInt64, deletedAt: String? = nil
  ) -> Variant {
    Variant(
      id: id, label: label, position: position,
      updatedAt: "2026-07-01T00:00:00+00:00", deletedAt: deletedAt)
  }

  func testVariantRowsRoundTripOrderedWithTombstonesIntact() throws {
    let store = try makeStore()
    var ex = item("e1", kind: .exercise)
    // Deliberately unordered, with a tombstoned step: load returns every row
    // (the core owns reconciliation and resurrect-by-label) in position order.
    ex.variants = [
      variant("v-f", label: "F", position: 1),
      variant("v-c", label: "C", position: 0),
      variant("v-g", label: "G", position: 2, deletedAt: "2026-07-02T00:00:00+00:00"),
    ]
    try store.save(ex)

    let got = try XCTUnwrap(try store.loadItems().first)
    XCTAssertEqual(got.variants.map(\.id), ["v-c", "v-f", "v-g"], "ladder order by position")
    XCTAssertEqual(got.variants.map(\.label), ["C", "F", "G"])
    XCTAssertEqual(
      got.variants[0].updatedAt, "2026-07-01T00:00:00+00:00",
      "per-step sync timestamp is preserved")
    XCTAssertEqual(
      got.variants[2].deletedAt, "2026-07-02T00:00:00+00:00",
      "the tombstone survives the round trip; no hard deletes")
  }

  func testVariantUpsertUpdatesRowsInPlace() throws {
    let store = try makeStore()
    var ex = item("e1", kind: .exercise)
    ex.variants = [variant("v-c", label: "C", position: 0)]
    try store.save(ex)
    ex.variants = [variant("v-c", label: "C", position: 1)]
    try store.save(ex)

    let got = try XCTUnwrap(try store.loadItems().first)
    XCTAssertEqual(got.variants.count, 1, "same id upserts, never duplicates")
    XCTAssertEqual(got.variants.first?.position, 1)
  }

  func testBatchSaveWritesEachItemsVariants() throws {
    let store = try makeStore()
    var a = item("a", kind: .exercise)
    a.variants = [variant("v-a", label: "C", position: 0)]
    var b = item("b", kind: .exercise)
    b.variants = [variant("v-b", label: "F", position: 0)]
    try store.save([a, b])

    let byId = Dictionary(
      uniqueKeysWithValues: try store.loadItems().map { ($0.id, $0.variants) })
    XCTAssertEqual(byId["a"]?.map(\.id), ["v-a"])
    XCTAssertEqual(byId["b"]?.map(\.id), ["v-b"])
  }

  /// Offline-first invariant #2: the variant child table carries the sync columns.
  func testVariantSchemaHasSyncColumns() throws {
    let columns = try makeStore().columnNames(ofTable: "variant")
    XCTAssertTrue(
      columns.contains("updated_at"), "variant table must carry updated_at; has \(columns)")
    XCTAssertTrue(
      columns.contains("deleted_at"), "variant table must carry deleted_at; has \(columns)")
  }

  // ── Sessions ──────────────────────────────────────────────────────────

  private func entry(_ id: String) -> SetlistEntry {
    SetlistEntry(
      id: id, itemId: "item-\(id)", itemTitle: "Etude", itemType: .exercise, position: 0,
      durationSecs: 300, status: .completed, notes: "good", intention: "evenness",
      plannedDurationSecs: 300, groupId: nil, plannedVariationId: nil, plannedRepTarget: 5,
      plays: [
        VariationPlay(
          id: "\(id)-p1", variationId: nil, startedAt: "2026-01-01T00:00:00Z", seconds: 300,
          repTarget: 5, repCount: 5, repTargetReached: true,
          repHistory: [
            RepEvent(action: .success, at: "2026-01-01T00:01:00Z"),
            RepEvent(action: .missed, at: "2026-01-01T00:02:00Z"),
            RepEvent(action: .success, at: "2026-01-01T00:03:30Z"),
          ], achievedTempo: 120, clickPattern: nil, score: 4)
      ])
  }

  private func session(_ id: String, completedAt: String = "2026-01-01T00:10:00Z")
    -> PracticeSession
  {
    PracticeSession(
      id: id, entries: [entry("a"), entry("b")], sessionNotes: "solid",
      startedAt: "2026-01-01T00:00:00Z", completedAt: completedAt,
      totalDurationSecs: 600, completionStatus: .completed, sessionScore: nil)
  }

  func testSaveThenLoadSessionRoundTrips() throws {
    let store = try makeStore()
    try store.saveSession(session("s1"))
    let got = try XCTUnwrap(try store.loadSessions().first)
    XCTAssertEqual(got.id, "s1")
    XCTAssertEqual(got.startedAt, "2026-01-01T00:00:00Z")
    XCTAssertEqual(got.completedAt, "2026-01-01T00:10:00Z")
    XCTAssertEqual(got.totalDurationSecs, 600)
    XCTAssertEqual(got.completionStatus, .completed)
    XCTAssertEqual(got.sessionNotes, "solid")
    XCTAssertEqual(got.entries.count, 2)
    let e = try XCTUnwrap(got.entries.first)
    XCTAssertEqual(e.itemType, .exercise)
    XCTAssertEqual(e.status, .completed)
    XCTAssertEqual(e.plannedRepTarget, 5)
    let play = try XCTUnwrap(e.plays.first)
    XCTAssertEqual(play.score, 4)
    XCTAssertEqual(play.repTarget, 5)
    XCTAssertEqual(
      play.repHistory,
      [
        RepEvent(action: .success, at: "2026-01-01T00:01:00Z"),
        RepEvent(action: .missed, at: "2026-01-01T00:02:00Z"),
        RepEvent(action: .success, at: "2026-01-01T00:03:30Z"),
      ], "each tap keeps its own time through the blob")
    XCTAssertEqual(play.achievedTempo, 120)
  }

  /// Rows written before #1367 hold bare action strings with no time. They
  /// must still decode, and the session start stands in for the missing `at`.
  func testLegacyUntimedRepHistoryDecodesAgainstTheSessionStart() throws {
    let entries =
      #"[{"id":"e1","itemId":"i1","itemTitle":"X","itemType":"piece","position":0,"durationSecs":0,"status":"completed","repTarget":5,"repCount":1,"repHistory":["success","missed"]}]"#
    let store = try LibraryStore.upgradeTestStore(
      migratedTo: "v3_session",
      seed: """
        INSERT INTO item
          (id, title, kind, composer, key, modality, tempo_marking, tempo_bpm, notes, tags,
           created_at, updated_at, priority, deleted_at)
        VALUES ('i1', 'X', 'piece', NULL, NULL, NULL, NULL, NULL, NULL, '[]',
                '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 0, NULL);
        INSERT INTO session
          (id, started_at, completed_at, total_duration_secs, completion_status,
           session_notes, session_intention, entries, updated_at, deleted_at)
        VALUES ('s1', '2026-01-01T09:00:00Z', '2026-01-01T09:30:00Z', 0, 'completed',
                NULL, NULL, '\(entries)', '2026-01-01T09:30:00Z', NULL)
        """)
    let e = try XCTUnwrap(try store.loadSessions().first?.entries.first)
    let play = try XCTUnwrap(e.plays.first, "a legacy completed entry folds into one play")
    XCTAssertEqual(
      play.repHistory,
      [
        RepEvent(action: .success, at: "2026-01-01T09:00:00Z"),
        RepEvent(action: .missed, at: "2026-01-01T09:00:00Z"),
      ], "an untimed legacy tap is dated to the session start, never dropped")
  }

  func testEndedEarlyAndEmptyEntriesRoundTrip() throws {
    let store = try makeStore()
    var s = session("s2")
    s.entries = []
    s.completionStatus = .endedEarly
    s.sessionNotes = nil
    try store.saveSession(s)
    let got = try XCTUnwrap(try store.loadSessions().first)
    XCTAssertEqual(got.completionStatus, .endedEarly)
    XCTAssertTrue(got.entries.isEmpty)
    XCTAssertNil(got.sessionNotes)
  }

  func testSkippedAndNotAttemptedEntryStatusRoundTrip() throws {
    let store = try makeStore()
    var s = session("s3")
    s.entries[0].status = .skipped
    s.entries[1].status = .notAttempted
    try store.saveSession(s)
    let got = try XCTUnwrap(try store.loadSessions().first)
    XCTAssertEqual(got.entries.map(\.status), [.skipped, .notAttempted])
  }

  func testEntriesBlobRoundTripsTheVariationAttribution() throws {
    let store = try makeStore()
    var s = session("s1")
    s.entries[0].plannedVariationId = "v-c"
    s.entries[0].plays[0].variationId = "v-c"
    try store.saveSession(s)

    let got = try XCTUnwrap(try store.loadSessions().first)
    XCTAssertEqual(got.entries[0].plannedVariationId, "v-c", "the plan rides the blob")
    XCTAssertEqual(
      got.entries[0].plays.first?.variationId, "v-c", "and so does what was practised")
    XCTAssertNil(got.entries[1].plannedVariationId)
    XCTAssertNil(got.entries[1].plays.first?.variationId)
  }

  func testEntriesBlobRoundTripsTheClickPattern() throws {
    let store = try makeStore()
    var s = session("s1")
    let pattern = ClickState(
      metre: Metre(beats: 7, unit: 8, groups: [3, 2, 2]), sounding: 0b0101001)
    s.entries[0].plays[0].clickPattern = pattern
    try store.saveSession(s)

    let got = try XCTUnwrap(try store.loadSessions().first)
    XCTAssertEqual(
      got.entries[0].plays.first?.clickPattern, pattern, "the pattern rides the blob")
    XCTAssertNil(got.entries[1].plays.first?.clickPattern)
  }

  func testSessionsLoadNewestFirst() throws {
    let store = try makeStore()
    try store.saveSession(session("old", completedAt: "2026-01-01T00:00:00Z"))
    try store.saveSession(session("new", completedAt: "2026-02-01T00:00:00Z"))
    XCTAssertEqual(try store.loadSessions().map(\.id), ["new", "old"])
  }

  func testSessionSchemaHasSyncColumns() throws {
    let columns = try makeStore().columnNames(ofTable: "session")
    XCTAssertTrue(columns.contains("updated_at"), "session needs updated_at; has \(columns)")
    XCTAssertTrue(columns.contains("deleted_at"), "session needs deleted_at; has \(columns)")
  }

  /// Unknown stored enum strings (an older binary reading a newer row) fall back
  /// to conservative defaults rather than silently miscategorising (#949).
  func testUnknownStoredEnumStringsFallBackToConservativeDefaults() throws {
    // The rep action rides a second, completed entry: an unknown status folds to
    // notAttempted, which keeps no play, so e1 has nowhere to carry a tap.
    let entries =
      #"[{"id":"e1","itemId":"i1","itemTitle":"X","itemType":"klingon","position":0,"durationSecs":0,"status":"quantum"},{"id":"e2","itemId":"i1","itemTitle":"X","itemType":"piece","position":1,"durationSecs":0,"status":"completed","repHistory":["warp"]}]"#
    let store = try LibraryStore.upgradeTestStore(
      migratedTo: "v3_session",
      seed: """
        INSERT INTO item
          (id, title, kind, composer, key, modality, tempo_marking, tempo_bpm, notes, tags,
           created_at, updated_at, priority, deleted_at)
        VALUES ('i1', 'X', 'piece', NULL, NULL, 'lydian', NULL, NULL, NULL, '[]',
                '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 0, NULL);
        INSERT INTO session
          (id, started_at, completed_at, total_duration_secs, completion_status,
           session_notes, session_intention, entries, updated_at, deleted_at)
        VALUES ('s1', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 0, 'enlightenment',
                NULL, NULL, '\(entries)', '2026-01-01T00:00:00Z', NULL)
        """)
    XCTAssertNil(try XCTUnwrap(try store.loadItems().first).modality, "unknown modality → nil")

    let got = try XCTUnwrap(try store.loadSessions().first)
    XCTAssertEqual(got.completionStatus, .completed, "unknown completion status → completed")
    let e = try XCTUnwrap(got.entries.first)
    XCTAssertEqual(
      e.status, .notAttempted, "unknown entry status → conservative notAttempted, not completed")
    XCTAssertEqual(e.itemType, .piece, "unknown kind → piece")
    let played = try XCTUnwrap(got.entries.last?.plays.first)
    XCTAssertEqual(
      played.repHistory?.map(\.action), [.missed], "unknown rep action → conservative missed")
  }

  /// Upgrade path: a pre-existing v2 item row survives the v3 session migration.
  func testV2ItemSurvivesSessionMigration() throws {
    let store = try LibraryStore.upgradeTestStore(
      migratedTo: "v2_add_modality",
      seed: """
        INSERT INTO item
          (id, title, kind, composer, key, modality, tempo_marking, tempo_bpm, notes, tags,
           created_at, updated_at, priority, deleted_at)
        VALUES ('p1', 'Legacy', 'piece', 'Bach', 'C', 'major', 'Allegro', 120, 'x',
                '["scale"]', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 0, NULL)
        """)
    XCTAssertEqual(try store.loadItems().count, 1, "the v2 item survives the v3 migration")
    XCTAssertTrue(try store.loadSessions().isEmpty, "the new session table starts empty")
  }
}
