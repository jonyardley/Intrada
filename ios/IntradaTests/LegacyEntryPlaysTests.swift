import GRDB
import SharedTypes
import Testing

@testable import Intrada

/// Every session row written before #1739 holds one score, one rep count and
/// one tempo on the entry itself, with no `plays`. They are not rewritten, so
/// `LibraryStore` folds them into a single play on the way out (#1739 decision
/// 8). The JSON below is the shape a shipped build wrote, not one invented to
/// match the decoder (#1256).
struct LegacyEntryPlaysTests {

  private func store(seeding entriesJSON: String) throws -> LibraryStore {
    let queue = try DatabaseQueue()
    try LibraryStore.migrator.migrate(queue)
    try queue.write { db in
      try db.execute(
        sql: """
          INSERT INTO session (id, started_at, completed_at, total_duration_secs,
            completion_status, session_notes, session_intention, entries, updated_at, deleted_at)
          VALUES ('s1','2026-09-01T10:00:00Z','2026-09-01T10:10:00Z',600,'completed',NULL,NULL,?,
            '2026-09-01T10:10:00Z',NULL)
          """, arguments: [entriesJSON])
    }
    return try LibraryStore(queue)
  }

  private func onlyEntry(_ store: LibraryStore) throws -> SetlistEntry {
    let sessions = try store.loadSessions()
    #expect(sessions.count == 1)
    let entries = try #require(sessions.first?.entries)
    #expect(entries.count == 1)
    return try #require(entries.first)
  }

  @Test("a fully populated legacy entry folds into one play carrying everything")
  func legacyEntryFoldsIntoOnePlay() throws {
    let json = """
      [{"id":"e1","itemId":"i1","itemTitle":"Major Scales","itemType":"exercise","position":0,\
      "durationSecs":600,"status":"completed","score":7,"intention":"even tone","repTarget":10,\
      "repCount":8,"repTargetReached":false,\
      "repHistory":[{"action":"success","at":"2026-09-01T10:01:00Z"},{"action":"missed",\
      "at":"2026-09-01T10:02:00Z"}],"plannedDurationSecs":600,"achievedTempo":120,\
      "groupId":"g1","variantId":"v-c"}]
      """

    let entry = try onlyEntry(try store(seeding: json))

    #expect(entry.plays.count == 1)
    let play = try #require(entry.plays.first)
    #expect(play.score == 7)
    #expect(play.repTarget == 10)
    #expect(play.repCount == 8)
    #expect(play.repTargetReached == false)
    #expect(play.repHistory?.count == 2)
    #expect(play.achievedTempo == 120)
    #expect(play.variationId == "v-c")
    #expect(play.seconds == 600)
    #expect(entry.groupId == "g1")
    #expect(entry.plannedVariationId == "v-c")
    #expect(entry.plannedRepTarget == 10)
  }

  /// Rows written before #1083 have no `variantId` at all. They still practised
  /// something, so they still get a play, unattributed.
  @Test("a legacy entry with no variation folds into one unattributed play")
  func legacyEntryWithoutAVariation() throws {
    let json = """
      [{"id":"e1","itemId":"i1","itemTitle":"Clair de Lune","itemType":"piece","position":0,\
      "durationSecs":420,"status":"completed","score":5}]
      """

    let entry = try onlyEntry(try store(seeding: json))

    #expect(entry.plays.count == 1)
    #expect(entry.plays.first?.variationId == nil)
    #expect(entry.plays.first?.score == 5)
    #expect(entry.plannedVariationId == nil)
  }

  /// Rows written before the rep history was timestamped hold bare action
  /// strings; the session start stands in for the missing time.
  @Test("a legacy entry with untimestamped repetitions still folds")
  func legacyEntryWithBareRepHistory() throws {
    let json = """
      [{"id":"e1","itemId":"i1","itemTitle":"Hanon No. 1","itemType":"exercise","position":0,\
      "durationSecs":300,"status":"completed","repTarget":5,"repCount":2,\
      "repHistory":["success","missed"]}]
      """

    let entry = try onlyEntry(try store(seeding: json))

    let play = try #require(entry.plays.first)
    #expect(play.repHistory?.count == 2)
    #expect(play.repHistory?.first?.at == "2026-09-01T10:00:00Z")
  }

  /// The old `SkipItem` froze rep state rather than discarding it, so rows like
  /// this exist on device: skipped, but with repetitions genuinely banked. The
  /// core still keeps that play, so the fold must not be stricter than the core
  /// and lose practice history that cannot be recovered.
  @Test("a legacy skipped entry that banked repetitions keeps its play")
  func legacySkippedEntryWithRepetitionsKeepsItsPlay() throws {
    let json = """
      [{"id":"e1","itemId":"i1","itemTitle":"Hanon No. 1","itemType":"exercise","position":0,\
      "durationSecs":0,"status":"skipped","repTarget":10,"repCount":4,\
      "repTargetReached":false}]
      """

    let entry = try onlyEntry(try store(seeding: json))

    #expect(entry.plays.count == 1)
    #expect(entry.plays.first?.repCount == 4)
    #expect(entry.plays.first?.repTarget == 10)
  }

  /// A skipped entry that banked nothing was not practised, so it keeps no
  /// play. Without this the fold would invent a record of something that never
  /// happened.
  @Test("a legacy skipped entry keeps no play")
  func legacySkippedEntryKeepsNoPlay() throws {
    let json = """
      [{"id":"e1","itemId":"i1","itemTitle":"Sight-reading","itemType":"exercise","position":0,\
      "durationSecs":0,"status":"skipped"}]
      """

    let entry = try onlyEntry(try store(seeding: json))

    #expect(entry.plays.isEmpty)
  }

  /// A row written after #1739 carries `plays`. If a stale legacy key survives
  /// beside it, the plays win: reading both would double-count the mark.
  @Test("plays win over the legacy keys when both are present")
  func playsWinOverLegacyKeys() throws {
    let json = """
      [{"id":"e1","itemId":"i1","itemTitle":"Major Scales","itemType":"exercise","position":0,\
      "durationSecs":600,"status":"completed","score":2,"variantId":"v-stale",\
      "plays":[{"id":"p1","variationId":"v-c","startedAt":"2026-09-01T10:00:00Z","seconds":300,\
      "score":8},{"id":"p2","variationId":"v-d","startedAt":"2026-09-01T10:05:00Z","seconds":300,\
      "score":6}]}]
      """

    let entry = try onlyEntry(try store(seeding: json))

    #expect(entry.plays.count == 2)
    #expect(entry.plays.map(\.score) == [8, 6])
    #expect(entry.plays.map(\.variationId) == ["v-c", "v-d"])
  }

  /// Two variations in one sitting is the case #1739 exists for, so it has to
  /// survive a write and a read unchanged.
  @Test("two plays round-trip through the JSON column")
  func twoPlaysRoundTrip() throws {
    let queue = try DatabaseQueue()
    let store = try LibraryStore(queue)
    let play = { (id: String, variation: String, score: UInt8) in
      VariationPlay(
        id: id, variationId: variation, startedAt: "2026-09-01T10:00:00Z", seconds: 300,
        repTarget: nil, repCount: nil, repTargetReached: nil, repHistory: nil,
        achievedTempo: nil, clickPattern: nil, score: score)
    }
    let entry = SetlistEntry(
      id: "e1", itemId: "i1", itemTitle: "Major Scales", itemType: .exercise, position: 0,
      durationSecs: 600, status: .completed, notes: nil, intention: nil,
      plannedDurationSecs: nil, groupId: nil, plannedVariationId: "v-c", plannedRepTarget: nil,
      plays: [play("p1", "v-c", 8), play("p2", "v-d", 6)])
    try store.saveSession(
      PracticeSession(
        id: "s1", entries: [entry], sessionNotes: nil,
        startedAt: "2026-09-01T10:00:00Z", completedAt: "2026-09-01T10:10:00Z",
        totalDurationSecs: 600, completionStatus: .completed, sessionScore: nil))

    let loaded = try onlyEntry(store)

    #expect(loaded.plays.count == 2)
    #expect(loaded.plays.map(\.id) == ["p1", "p2"])
    #expect(loaded.plays.map(\.score) == [8, 6])
    #expect(loaded.plannedVariationId == "v-c")
  }
}
