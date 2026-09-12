import SharedTypes
import Testing

@testable import Intrada

/// The shell-side derivations #1739 Phase B added: what the item-complete
/// sheet's rows say, and what the Progress screen counts.
struct VariationScreenTests {

  private func play(
    _ id: String, _ label: String?, seconds: UInt64, tempo: UInt16? = nil,
    repCount: UInt8? = nil, repTarget: UInt8? = nil
  ) -> VariationPlayView {
    VariationPlayView(
      id: id, variationId: label.map { "v-\($0)" }, variationLabel: label, seconds: seconds,
      durationDisplay: "4m 10s", repTarget: repTarget, repCount: repCount,
      repTargetReached: nil, repHistory: nil, achievedTempo: tempo, clickPattern: nil,
      score: nil)
  }

  // ── The sheet's rows ──

  @Test("the open play takes the elapsed time the closed plays have not claimed")
  func openPlayTakesTheRemainder() {
    let rows = ReflectionPlay.rows(
      [play("p1", "C", seconds: 250), play("p2", "G", seconds: 0)], elapsed: 760)

    #expect(rows.map(\.durationDisplay) == ["04:10", "08:30"])
  }

  @Test("a closed play keeps its own seconds rather than sharing the remainder")
  func closedPlaysKeepTheirOwnSeconds() {
    let rows = ReflectionPlay.rows(
      [play("p1", "C", seconds: 250), play("p2", "G", seconds: 200), play("p3", "D", seconds: 0)],
      elapsed: 760)

    #expect(rows.map(\.durationDisplay) == ["04:10", "03:20", "05:10"])
  }

  @Test("one play takes the whole of the item's elapsed time")
  func aSinglePlayTakesTheWholeElapsed() {
    let rows = ReflectionPlay.rows([play("p1", nil, seconds: 0)], elapsed: 420)

    #expect(rows.map(\.durationDisplay) == ["07:00"])
  }

  /// The clock and the stamped seconds come from different instants, so the
  /// arithmetic can go negative on a fast switch. A row reading minus four
  /// minutes would be worse than one reading zero.
  @Test("an elapsed shorter than what the closed plays claim floors at zero")
  func theRemainderNeverGoesNegative() {
    let rows = ReflectionPlay.rows(
      [play("p1", "C", seconds: 250), play("p2", "G", seconds: 0)], elapsed: 10)

    #expect(rows.last?.durationDisplay == "00:00")
  }

  @Test("a row names its variation, and an unattributed play says so")
  func rowsCarryTheirLabel() {
    let rows = ReflectionPlay.rows(
      [play("p1", "C major", seconds: 0), play("p2", nil, seconds: 0)], elapsed: 0)

    #expect(rows.map(\.title) == ["C major", "No variation"])
  }

  @Test("a row shows repetitions only when the entry set a target")
  func rowMetaShowsRepetitionsOnlyAgainstATarget() {
    let withTarget = ReflectionPlay.rows(
      [play("p1", "C", seconds: 0, repCount: 8, repTarget: 10)], elapsed: 250)
    let without = ReflectionPlay.rows(
      [play("p1", "C", seconds: 0, repCount: 8)], elapsed: 250)

    #expect(withTarget.first?.meta == "04:10 · 8 of 10")
    #expect(without.first?.meta == "04:10")
  }

  @Test("a target with no repetitions banked reads as none of the target, not blank")
  func rowMetaCountsZeroAgainstTheTarget() {
    let rows = ReflectionPlay.rows([play("p1", "C", seconds: 0, repTarget: 10)], elapsed: 250)

    #expect(rows.first?.meta == "04:10 · 0 of 10")
  }

  // ── The read-only meta line ──

  @Test("a play's meta names only what it measured")
  func metaPartsStateOnlyWhatWasMeasured() {
    #expect(play("p", "C", seconds: 250).metaParts == ["4m 10s"])
    #expect(play("p", "C", seconds: 250, tempo: 96).metaParts == ["4m 10s", "96 bpm"])
    #expect(
      play("p", "C", seconds: 250, tempo: 96, repCount: 8, repTarget: 10).metaParts
        == ["4m 10s", "96 bpm", "8 of 10 reps"])
  }

  @Test("an unattributed play is named rather than left blank")
  func unattributedPlaysAreNamed() {
    #expect(play("p", nil, seconds: 0).displayLabel == "No variation")
    #expect(play("p", "B♭ major", seconds: 0).displayLabel == "B♭ major")
  }

  // ── The Progress screen's coverage ──

  private func exercise(
    _ id: String, variations: [(String, Bool)], sessions: UInt64, lastPractised: String?
  ) -> LibraryItemView {
    LibraryItemView(
      id: id, itemType: .exercise, title: id, subtitle: "", key: nil, modality: nil,
      tempo: nil, tempoMarking: nil, tempoBpm: nil, notes: nil, tags: [], createdAt: "",
      updatedAt: "",
      practice: sessions == 0
        ? nil
        : ItemPracticeSummary.fixture(sessionCount: sessions, lastPracticedAt: lastPractised),
      latestAchievedTempo: nil, priority: false, linkedExercises: [], usedIn: [],
      scaffoldPreview: nil, chordChart: nil, metre: nil,
      variants: variations.enumerated().map { index, variation in
        VariantView(
          id: "\(id)-\(index)", label: variation.0, position: UInt64(index),
          latestScore: variation.1 ? 9 : nil, scoreHistory: [], isSolid: variation.1)
      }, ladderIsKeys: true, photoId: nil)
  }

  @Test("coverage counts the solid variations of each practised exercise")
  func coverageCountsSolidVariations() {
    let rows = VariationCoverage.rows([
      exercise(
        "Scales", variations: [("C", true), ("G", true), ("D", false)], sessions: 4,
        lastPractised: "2026-09-01T10:00:00Z")
    ])

    #expect(rows.map(\.solid) == [2])
    #expect(rows.map(\.total) == [3])
  }

  @Test("an exercise nobody has practised has nothing to report")
  func coverageSkipsTheUnpractised() {
    let rows = VariationCoverage.rows([
      exercise("Cold", variations: [("C", false), ("G", false)], sessions: 0, lastPractised: nil)
    ])

    #expect(rows.isEmpty)
  }

  /// One variation is not a set worth a bar: the exercise's own screen says it
  /// better than a single full-width segment would.
  @Test("a single variation is not a coverage row")
  func coverageSkipsASingleVariation() {
    let rows = VariationCoverage.rows([
      exercise("One", variations: [("C", true)], sessions: 4, lastPractised: "2026-09-01T10:00:00Z")
    ])

    #expect(rows.isEmpty)
  }

  @Test("coverage leads with the most recently practised")
  func coverageOrdersByLastPractised() {
    let rows = VariationCoverage.rows([
      exercise(
        "Older", variations: [("C", true), ("G", false)], sessions: 4,
        lastPractised: "2026-08-01T10:00:00Z"),
      exercise(
        "Newer", variations: [("C", true), ("G", false)], sessions: 4,
        lastPractised: "2026-09-01T10:00:00Z"),
    ])

    #expect(rows.map(\.title) == ["Newer", "Older"])
  }

  @Test("coverage stops at the limit rather than taking the screen over")
  func coverageCapsTheRows() {
    let items = (0..<8).map { index in
      exercise(
        "Ex\(index)", variations: [("C", true), ("G", false)], sessions: 4,
        lastPractised: "2026-09-0\(index + 1)T10:00:00Z")
    }

    #expect(VariationCoverage.rows(items).count == 5)
    #expect(VariationCoverage.rows(items, limit: 2).map(\.title) == ["Ex7", "Ex6"])
  }
}
