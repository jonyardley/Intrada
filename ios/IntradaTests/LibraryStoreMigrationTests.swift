import GRDB
import SharedTypes
import XCTest

@testable import Intrada

final class LibraryStoreMigrationTests: XCTestCase {
  func testV5RescalesEntryScoresAndAddsSessionScore() throws {
    let queue = try DatabaseQueue()  // in-memory

    // Migrate only up to v3 (the pre-rescale schema), then seed a session
    // whose single entry scored 3 on the old 1–5 scale.
    try LibraryStore.migrator.migrate(queue, upTo: "v3_session")
    try queue.write { db in
      let entriesJSON =
        #"[{"id":"e1","itemId":"i1","itemTitle":"Scales","itemType":"exercise","position":0,"durationSecs":60,"status":"completed","score":3}]"#
      try db.execute(
        sql: """
          INSERT INTO session (id, started_at, completed_at, total_duration_secs,
            completion_status, session_notes, session_intention, entries, updated_at, deleted_at)
          VALUES ('s1','2026-01-01T00:00:00Z','2026-01-01T00:01:00Z',60,'completed',NULL,NULL,?, '2026-01-01T00:00:00Z',NULL)
          """, arguments: [entriesJSON])
    }

    // Run the remaining migrations (v4 add column, v5 rescale).
    try LibraryStore.migrator.migrate(queue)

    try queue.read { db in
      let row = try Row.fetchOne(
        db, sql: "SELECT entries, session_score FROM session WHERE id='s1'")!
      let entries: String = row["entries"]
      XCTAssertTrue(entries.contains("\"score\":6"), "old score 3 should rescale ×2 to 6")
      XCTAssertNil(row["session_score"] as Int64?, "session_score column exists, null for old rows")
    }
  }

  func testSessionScoreRoundTrip() throws {
    let store = try LibraryStore.inMemory()
    let entry = SetlistEntry(
      id: "e1", itemId: "i1", itemTitle: "Scales", itemType: .exercise,
      position: 0, durationSecs: 60, status: .completed,
      notes: nil, intention: nil, plannedDurationSecs: nil,
      groupId: nil, plannedVariationId: nil, plannedRepTarget: nil,
      plays: [
        VariationPlay(
          id: "e1-p1", variationId: nil, startedAt: "2026-01-01T10:00:00Z", seconds: 60,
          repTarget: nil, repCount: nil, repTargetReached: nil, repHistory: nil,
          achievedTempo: nil, clickPattern: nil, score: 8)
      ])
    let session = PracticeSession(
      id: "sess-rt", entries: [entry],
      sessionNotes: nil,
      startedAt: "2026-01-01T10:00:00Z", completedAt: "2026-01-01T10:30:00Z",
      totalDurationSecs: 1800, completionStatus: .completed, sessionScore: 7)
    try store.saveSession(session)
    let loaded = try store.loadSessions()
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(
      loaded[0].sessionScore, 7,
      "sessionScore UInt8→Int64→UInt8(clamping:) round-trip must preserve 7")
  }

  func testV6SessionSurvivesReflectionMigration() throws {
    let store = try LibraryStore.upgradeTestStore(
      migratedTo: "v6_item_linked_exercises",
      seed: """
        INSERT INTO session
          (id, started_at, completed_at, total_duration_secs, completion_status,
           session_notes, session_intention, entries, updated_at, deleted_at, session_score)
        VALUES ('s-pre', '2026-01-01T00:00:00Z', '2026-01-01T00:01:00Z', 60, 'completed',
                'old note', NULL, '[]', '2026-01-01T00:00:00Z', NULL, 7)
        """)
    let loaded = try XCTUnwrap(try store.loadSessions().first)
    XCTAssertEqual(loaded.sessionNotes, "old note", "pre-migration row survives intact")
    XCTAssertEqual(loaded.sessionScore, 7)
  }

  /// #1766 retired the intention and the reflection trio from the store but
  /// kept their columns, so text typed before the retirement is still the only
  /// copy there is. Nothing else reads those columns any more, so this is what
  /// stands between them and a tidy-up.
  func testRetiredSessionColumnsAndTheirTextSurviveASave() throws {
    let queue = try DatabaseQueue()
    let store = try LibraryStore(queue)
    try queue.write { db in
      try db.execute(
        sql: """
          INSERT INTO session
            (id, started_at, completed_at, total_duration_secs, completion_status,
             session_notes, session_intention, entries, updated_at, deleted_at,
             reflection_improved, reflection_still_rough, reflection_next_target)
          VALUES ('s-old', '2026-05-01T10:00:00Z', '2026-05-01T10:30:00Z', 1800, 'completed',
                  'old note', 'even RH at 96', '[]', '2026-05-01T10:30:00Z', NULL,
                  'thumb-unders even', 'bars 12-14 rush', 'bars 12-14 at 80')
          """)
    }

    let columns = try store.columnNames(ofTable: "session")
    for retired in [
      "session_intention", "reflection_improved", "reflection_still_rough",
      "reflection_next_target",
    ] {
      XCTAssertTrue(columns.contains(retired), "\(retired) must stay in the table; got \(columns)")
    }

    var reloaded = try XCTUnwrap(try store.loadSessions().first)
    reloaded.sessionNotes = "edited"
    try store.saveSession(reloaded)

    try queue.read { db in
      let row = try XCTUnwrap(try Row.fetchOne(db, sql: "SELECT * FROM session WHERE id = 's-old'"))
      let notes: String? = row["session_notes"]
      XCTAssertEqual(notes, "edited", "the save still writes the columns the app holds")
      let intention: String? = row["session_intention"]
      XCTAssertEqual(intention, "even RH at 96", "a re-save must not wipe the retired columns")
      let improved: String? = row["reflection_improved"]
      XCTAssertEqual(improved, "thumb-unders even")
      let stillRough: String? = row["reflection_still_rough"]
      XCTAssertEqual(stillRough, "bars 12-14 rush")
      let nextTarget: String? = row["reflection_next_target"]
      XCTAssertEqual(nextTarget, "bars 12-14 at 80")
    }
  }

  func testGroupIdRoundTripsThroughTheJsonCodec() throws {
    let store = try LibraryStore.inMemory()
    let entry = SetlistEntry(
      id: "e1", itemId: "i1", itemTitle: "Scales", itemType: .exercise,
      position: 0, durationSecs: 60, status: .completed,
      notes: nil, intention: nil, plannedDurationSecs: nil,
      groupId: "block-1", plannedVariationId: nil, plannedRepTarget: nil,
      plays: [
        VariationPlay(
          id: "e1-p1", variationId: nil, startedAt: "2026-01-01T10:00:00Z", seconds: 60,
          repTarget: nil, repCount: nil, repTargetReached: nil, repHistory: nil,
          achievedTempo: nil, clickPattern: nil, score: nil)
      ])
    let session = PracticeSession(
      id: "sess-g", entries: [entry],
      sessionNotes: nil,
      startedAt: "2026-01-01T10:00:00Z", completedAt: "2026-01-01T10:30:00Z",
      totalDurationSecs: 60, completionStatus: .completed, sessionScore: nil)
    try store.saveSession(session)
    let loaded = try store.loadSessions()
    XCTAssertEqual(
      loaded.first?.entries.first?.groupId, "block-1",
      "group_id round-trips through the JSON-blob codec")
  }

  func testV5RescaleClampNilAndBlobPreservation() throws {
    let queue = try DatabaseQueue()

    // Seed at v3: one entry with score 5 (boundary — should clamp to 10) and notes,
    // one entry with no score (null — must remain null after rescale).
    try LibraryStore.migrator.migrate(queue, upTo: "v3_session")
    try queue.write { db in
      let entriesJSON =
        #"[{"id":"e1","itemId":"i1","itemTitle":"Bach","itemType":"piece","position":0,"durationSecs":120,"status":"completed","score":5,"notes":"keep"},{"id":"e2","itemId":"i2","itemTitle":"Scales","itemType":"exercise","position":1,"durationSecs":60,"status":"completed"}]"#
      try db.execute(
        sql: """
          INSERT INTO session (id, started_at, completed_at, total_duration_secs,
            completion_status, session_notes, session_intention, entries, updated_at, deleted_at)
          VALUES ('s2','2026-01-02T00:00:00Z','2026-01-02T00:02:00Z',120,'completed',NULL,NULL,?, '2026-01-02T00:00:00Z',NULL)
          """, arguments: [entriesJSON])
    }

    try LibraryStore.migrator.migrate(queue)

    try queue.read { db in
      let row = try Row.fetchOne(db, sql: "SELECT entries FROM session WHERE id='s2'")!
      let entries: String = row["entries"]
      // Score 5 × 2 = 10 — at the clamp boundary.
      XCTAssertTrue(entries.contains("\"score\":10"), "score 5 must clamp to 10 after ×2 rescale")
      // The notes field on entry e1 must survive the decode→re-encode round-trip.
      XCTAssertTrue(
        entries.contains("\"notes\":\"keep\""), "notes field must survive blob re-encode")
      // Entry e2 had no score key — must still have no score after rescale.
      XCTAssertFalse(entries.contains("\"score\":0"), "null-score entry must not gain a zero score")
    }
  }

  // ── v6: linked_exercise_ids ───────────────────────────────────────────

  func testV6AddsLinkedExerciseIdsColumnDefaultingToEmptyArray() throws {
    // Populate at v5 (no linked_exercise_ids column), insert an item row, then finish.
    let store = try LibraryStore.upgradeTestStore(
      migratedTo: "v5_rescale_entry_scores",
      seed: """
        INSERT INTO item
          (id, title, kind, composer, key, modality, tempo_marking, tempo_bpm, notes, tags,
           created_at, updated_at, priority, deleted_at)
        VALUES ('p1', 'Legacy Piece', 'piece', NULL, NULL, NULL, NULL, NULL, NULL, '[]',
                '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 0, NULL)
        """)
    let columns = try store.columnNames(ofTable: "item")
    XCTAssertTrue(
      columns.contains("linked_exercise_ids"),
      "v6 must add linked_exercise_ids column; got \(columns)")

    let loaded = try store.loadItems()
    XCTAssertEqual(loaded.count, 1, "pre-existing row must survive v6 migration")
    XCTAssertEqual(
      loaded[0].linkedExerciseIds, [],
      "pre-existing row gets empty-array default for linked_exercise_ids")
  }

  func testV8AddsChordChartColumnDefaultingToNull() throws {
    // Populate at v7 (no chord_chart column), insert an item row, then finish.
    let store = try LibraryStore.upgradeTestStore(
      migratedTo: "v7_session_reflections",
      seed: """
        INSERT INTO item
          (id, title, kind, composer, key, modality, tempo_marking, tempo_bpm, notes, tags,
           linked_exercise_ids, created_at, updated_at, priority, deleted_at)
        VALUES ('p1', 'Legacy Piece', 'piece', NULL, NULL, NULL, NULL, NULL, NULL, '[]',
                '[]', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 0, NULL)
        """)
    let columns = try store.columnNames(ofTable: "item")
    XCTAssertTrue(
      columns.contains("chord_chart"),
      "v8 must add chord_chart column; got \(columns)")

    let loaded = try store.loadItems()
    XCTAssertEqual(loaded.count, 1, "pre-existing row must survive v8 migration")
    XCTAssertNil(loaded[0].chordChart, "pre-existing row defaults to no chart")
  }

  func testV9CreatesVariantTableAndPreservesRows() throws {
    // Populate at v8 (no variant table), insert an exercise row, then finish.
    let store = try LibraryStore.upgradeTestStore(
      migratedTo: "v8_item_chord_chart",
      seed: """
        INSERT INTO item
          (id, title, kind, composer, key, modality, tempo_marking, tempo_bpm, notes, tags,
           linked_exercise_ids, created_at, updated_at, priority, deleted_at, chord_chart)
        VALUES ('e1', 'Legacy Exercise', 'exercise', NULL, NULL, NULL, NULL, NULL, NULL, '[]',
                '[]', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 0, NULL, NULL)
        """)
    let columns = try store.columnNames(ofTable: "variant")
    for expected in ["id", "item_id", "label", "position", "updated_at", "deleted_at"] {
      XCTAssertTrue(
        columns.contains(expected), "v9 variant table must carry \(expected); got \(columns)")
    }

    let loaded = try store.loadItems()
    XCTAssertEqual(loaded.count, 1, "pre-existing row must survive v9 migration")
    XCTAssertEqual(loaded[0].variants, [], "a pre-v9 exercise starts with an empty ladder")
  }

  func testV9OldEntriesBlobDecodesWithNilVariantId() throws {
    // A session written before variantId existed must decode with the
    // attribution absent; the blob is keyed JSON, so no migration runs.
    let entries =
      #"[{"id":"e1","itemId":"i1","itemTitle":"Scales","itemType":"exercise","position":0,"durationSecs":60,"status":"completed","score":6}]"#
    let store = try LibraryStore.upgradeTestStore(
      migratedTo: "v8_item_chord_chart",
      seed: """
        INSERT INTO session
          (id, started_at, completed_at, total_duration_secs, completion_status,
           session_notes, session_intention, entries, updated_at, deleted_at)
        VALUES ('s1', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 60, 'completed',
                NULL, NULL, '\(entries)', '2026-01-01T00:00:00Z', NULL)
        """)

    let got = try XCTUnwrap(try store.loadSessions().first)
    let entry = try XCTUnwrap(got.entries.first)
    let play = try XCTUnwrap(entry.plays.first, "the old blob folds into one play")
    XCTAssertEqual(play.score, 6, "the old blob still decodes in full")
    XCTAssertNil(play.variationId, "a pre-variant entry reads as unattributed")
    XCTAssertNil(entry.plannedVariationId, "and it carries no plan either")
  }

  func testV16AddsPhotoIdColumnWithExistingItemsIntact() throws {
    // Populate at v15 (no photo_id column), then finish the chain — the upgrade
    // path is what matters, since on the free tier the device is the only copy.
    let store = try LibraryStore.upgradeTestStore(
      migratedTo: "v15_reflection_steer",
      seed: """
        INSERT INTO item
          (id, title, kind, composer, key, modality, tempo_marking, tempo_bpm, notes, tags,
           linked_exercise_ids, created_at, updated_at, priority, deleted_at, chord_chart)
        VALUES ('p1', 'Legacy Piece', 'piece', 'Chopin', 'E', NULL, NULL, NULL, NULL, '[]',
                '[]', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 0, NULL, NULL)
        """)

    let columns = try store.columnNames(ofTable: "item")
    XCTAssertTrue(columns.contains("photo_id"), "v16 must add photo_id; got \(columns)")

    let loaded = try store.loadItems()
    XCTAssertEqual(loaded.count, 1, "the pre-existing row survives v16")
    XCTAssertEqual(loaded[0].title, "Legacy Piece")
    XCTAssertEqual(loaded[0].composer, "Chopin", "the migration is additive, not a rebuild")
    XCTAssertNil(loaded[0].photoId, "an item added before photos existed has none")
  }

  func testV16PhotoIdRoundTripsAndClears() throws {
    let store = try LibraryStore.inMemory()
    let item = Item(
      id: "p1", title: "Nocturne", kind: .piece, composer: "Chopin", key: nil, modality: nil,
      tempo: nil, notes: nil, tags: [], linkedExerciseIds: [],
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", priority: false,
      chordChart: nil, variants: [], photoId: "01ARZ3NDEKTSV4RRFFQ69G5FAV", metre: nil)
    try store.save(item)
    XCTAssertEqual(try store.loadItems().first?.photoId, "01ARZ3NDEKTSV4RRFFQ69G5FAV")

    // A removal is an upsert with no photo, so the column has to clear rather
    // than keep the id the row already held.
    try store.save(
      Item(
        id: "p1", title: "Nocturne", kind: .piece, composer: "Chopin", key: nil, modality: nil,
        tempo: nil, notes: nil, tags: [], linkedExerciseIds: [],
        createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:01:00Z", priority: false,
        chordChart: nil, variants: [], photoId: nil, metre: nil))
    XCTAssertNil(try store.loadItems().first?.photoId, "removing a photo must clear the column")
  }

  /// Upgrade path (#1499): a piece charted before v17 keeps its beats-per-bar
  /// as a crotchet-unit metre on the item; an uncharted piece declares none.
  func testV16ChartedPieceGetsItsMetreInV17() throws {
    let chart = #"{"key":"G","modality":"minor","metre":3,"sections":[]}"#
    let store = try LibraryStore.upgradeTestStore(
      migratedTo: "v16_item_photo",
      seed: """
        INSERT INTO item
          (id, title, kind, composer, key, modality, tempo_marking, tempo_bpm, notes, tags,
           linked_exercise_ids, created_at, updated_at, priority, chord_chart, photo_id, deleted_at)
        VALUES ('p1', 'Waltz', 'piece', NULL, 'G', 'minor', NULL, NULL, NULL, '[]', '[]',
                '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 0, '\(chart)', NULL, NULL);
        INSERT INTO item
          (id, title, kind, composer, key, modality, tempo_marking, tempo_bpm, notes, tags,
           linked_exercise_ids, created_at, updated_at, priority, chord_chart, photo_id, deleted_at)
        VALUES ('p2', 'Plain', 'piece', NULL, NULL, NULL, NULL, NULL, NULL, '[]', '[]',
                '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 0, NULL, NULL, NULL)
        """)
    let items = try store.loadItems()
    let charted = try XCTUnwrap(items.first { $0.id == "p1" })
    XCTAssertEqual(
      charted.metre, Metre(beats: 3, unit: 4, groups: nil),
      "the chart's beats become the item's metre in crotchets")
    XCTAssertNotNil(charted.chordChart, "the chart itself still decodes")
    XCTAssertNil(try XCTUnwrap(items.first { $0.id == "p2" }).metre)
  }

  func testMetreRoundTrips() throws {
    let store = try LibraryStore.inMemory()
    let metre = Metre(beats: 7, unit: 8, groups: [3, 2, 2])
    try store.save(
      Item(
        id: "p7", title: "Unsquare", kind: .piece, composer: nil, key: nil, modality: nil,
        tempo: nil, notes: nil, tags: [], linkedExerciseIds: [],
        createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", priority: false,
        chordChart: nil, variants: [], photoId: nil, metre: metre))
    XCTAssertEqual(try store.loadItems().first?.metre, metre)
  }

  func testV8ChordChartRoundTrip() throws {
    let store = try LibraryStore.inMemory()
    let symbol = ChordSymbol(
      root: 0, quality: .min7, extensions: [], bass: 7, raw: "Cm7/G")
    let chart = ChordChart(
      key: "G", modality: .minor,
      sections: [
        ChartSection(
          label: "A",
          bars: [Bar(chords: [ChartChord(symbol: symbol, beats: 4)])])
      ])
    let item = Item(
      id: "p3", title: "Autumn Leaves", kind: .piece, composer: nil, key: "G",
      modality: .minor, tempo: nil, notes: nil, tags: [], linkedExerciseIds: [],
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", priority: false,
      chordChart: chart, variants: [], photoId: nil, metre: nil)
    try store.save(item)
    let loaded = try store.loadItems()
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(
      loaded[0].chordChart, chart,
      "chord_chart must round-trip through JSON storage intact")
  }

  func testV11BuiltSessionTablesArriveWithV10DataIntact() throws {
    let queue = try DatabaseQueue()  // in-memory

    // A device that stopped at v10, with real rows in the tables that exist there.
    try LibraryStore.migrator.migrate(queue, upTo: "v10_coach_records")
    try queue.write { db in
      try db.execute(
        sql: """
          INSERT INTO item (id, title, kind, tags, created_at, updated_at)
          VALUES ('i1', 'Alice in Wonderland', 'piece', '[]',
                  '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
          """)
      try db.execute(
        sql: """
          INSERT INTO block_record (id, node, drill, gate, level_tempo_bpm, level_click_level,
            circle, mode, started_at, ended_at, attempts, reps_after_gate, active_ms,
            escalation_fired, exit, updated_at)
          VALUES ('b1', 'n', 'd', 'g', 72, 'every_beat', 'hands', 'keys',
                  '2026-01-01T00:00:00Z', '2026-01-01T00:01:00Z', '[]', 0, 60000, '[]',
                  'gate_passed', '2026-01-01T00:01:00Z')
          """)
    }

    // The remaining chain must run cleanly from v10.
    try LibraryStore.migrator.migrate(queue)

    try queue.read { db in
      XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item"), 1)
      XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM block_record"), 1)
      for table in [
        "user_drill", "journal_item", "built_session", "play_through", "reflection", "feel_entry",
      ] {
        XCTAssertTrue(try db.tableExists(table), "\(table) must exist after v11")
        XCTAssertEqual(
          try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)"), 0,
          "\(table) starts empty on upgrade")
        let columns = try db.columns(in: table).map(\.name)
        XCTAssertTrue(columns.contains("updated_at"), "\(table) is sync-ready (invariant 2)")
        XCTAssertTrue(columns.contains("deleted_at"), "\(table) carries a tombstone (invariant 2)")
      }
    }
  }

  func testV6LinkedExerciseIdsRoundTrip() throws {
    let store = try LibraryStore.inMemory()
    let item = Item(
      id: "p2", title: "Étude", kind: .piece, composer: nil, key: nil, modality: nil,
      tempo: nil, notes: nil, tags: [], linkedExerciseIds: ["e1", "e2"],
      createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z", priority: false,
      chordChart: nil, variants: [], photoId: nil, metre: nil)
    try store.save(item)
    let loaded = try store.loadItems()
    XCTAssertEqual(loaded.count, 1)
    XCTAssertEqual(
      loaded[0].linkedExerciseIds, ["e1", "e2"],
      "linked_exercise_ids must round-trip through JSON storage intact")
  }

  /// #1256: `block_record.origin` arrives with built sessions. A record written
  /// before they existed can only have been the planner's, so it must come
  /// through as `authored` — the value the mastery rebuild reads to decide
  /// whether a block's taps were ever evidence (decision 17). Get this wrong
  /// and every historic block silently stops counting.
  func testV12BackfillsBlockOriginOnRecordsWrittenBeforeBuiltSessions() throws {
    let queue = try DatabaseQueue()
    try LibraryStore.migrator.migrate(queue, upTo: "v11_built_session")
    try queue.write { db in
      try db.execute(
        sql: """
          INSERT INTO block_record
            (id, node, drill, gate, level_tempo_bpm, level_click_level, circle, mode,
             started_at, ended_at, attempts, attempts_to_pass, gate_opened_at_attempt,
             reps_after_gate, active_ms, escalation_fired, exit, updated_at, deleted_at)
          VALUES ('b1','rootless-a-b','shell-voicings','rootless-under-melody',92,'two_and_four',
            'hands','keys','2026-08-04T10:00:00Z','2026-08-04T10:00:30Z','[]',3,3,0,30000,'[]',
            'gate_passed','2026-08-04T10:00:30Z',NULL)
          """)
    }

    try LibraryStore.migrator.migrate(queue)

    try queue.read { db in
      XCTAssertEqual(
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM block_record"), 1,
        "the historic record survives the upgrade")
      XCTAssertEqual(
        try String.fetchOne(db, sql: "SELECT origin FROM block_record WHERE id = 'b1'"),
        "authored",
        "a record from before built sessions is the planner's backfill")
      XCTAssertEqual(
        try String.fetchOne(db, sql: "SELECT node FROM block_record WHERE id = 'b1'"),
        "rootless-a-b", "the rest of the row is untouched")
    }
  }
}
