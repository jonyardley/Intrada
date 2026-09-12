import SharedTypes
import XCTest

@testable import Intrada

/// Real-bridge bincode round-trip for #1739. A stub bridge cannot catch the
/// #846 silent-drop class, so this drives start, switch, score and finish
/// through `LiveBridge` and reads the result back off the ViewModel.
final class VariationPlayBridgeTests: XCTestCase {

  private func exerciseWithTwoVariations(_ bridge: LiveBridge) throws -> String {
    _ = try bridge.update(.startApp(apiBaseUrl: "http://localhost:3001", localFirst: true))
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Major Scales", kind: .exercise, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let id = try XCTUnwrap(try bridge.view().items.first?.id)
    _ = try bridge.update(.item(.setVariants(id: id, labels: ["C", "D"])))
    return id
  }

  private func variationId(_ bridge: LiveBridge, label: String) throws -> String {
    let variants = try XCTUnwrap(try bridge.view().items.first?.variants)
    return try XCTUnwrap(variants.first(where: { $0.label == label })?.id)
  }

  func testSwitchingMidItemRecordsTwoPlaysOverTheRealBridge() throws {
    let bridge = LiveBridge()
    let itemId = try exerciseWithTwoVariations(bridge)
    let inC = try variationId(bridge, label: "C")
    let inD = try variationId(bridge, label: "D")

    _ = try bridge.update(.session(.startBuilding))
    _ = try bridge.update(.session(.addToSetlist(itemId: itemId)))
    let entryId = try XCTUnwrap(
      try bridge.view().buildingSetlist?.entries.first?.id)
    _ = try bridge.update(.session(.setEntryVariant(entryId: entryId, variantId: inC)))
    _ = try bridge.update(.session(.startSession(now: "2026-09-01T10:00:00Z")))

    let atStart = try XCTUnwrap(try bridge.view().activeSession)
    XCTAssertEqual(atStart.currentVariationId, inC, "the plan seeds the first play")
    XCTAssertEqual(atStart.currentVariationLabel, "C")

    _ = try bridge.update(
      .session(
        .switchVariation(entryId: entryId, variationId: inD, now: "2026-09-01T10:05:00Z")))

    let afterSwitch = try XCTUnwrap(try bridge.view().activeSession)
    let entry = try XCTUnwrap(afterSwitch.entries.first)
    XCTAssertEqual(entry.plays.count, 2, "the switch closed one play and opened another")
    XCTAssertEqual(entry.plays.first?.variationId, inC)
    XCTAssertEqual(entry.plays.first?.seconds, 300)
    XCTAssertEqual(entry.plays.last?.variationId, inD)
    XCTAssertEqual(afterSwitch.currentVariationLabel, "D")
  }

  func testScoringEachPlayLandsOnItsOwnRowOverTheRealBridge() throws {
    let bridge = LiveBridge()
    let itemId = try exerciseWithTwoVariations(bridge)
    let inD = try variationId(bridge, label: "D")

    _ = try bridge.update(.session(.startBuilding))
    _ = try bridge.update(.session(.addToSetlist(itemId: itemId)))
    let entryId = try XCTUnwrap(try bridge.view().buildingSetlist?.entries.first?.id)
    _ = try bridge.update(.session(.startSession(now: "2026-09-01T10:00:00Z")))
    _ = try bridge.update(
      .session(
        .switchVariation(entryId: entryId, variationId: inD, now: "2026-09-01T10:05:00Z")))
    _ = try bridge.update(.session(.finishSession(now: "2026-09-01T10:10:00Z")))

    let plays = try XCTUnwrap(try bridge.view().summary?.entries.first?.plays)
    XCTAssertEqual(plays.count, 2)

    _ = try bridge.update(
      .session(.updateEntryScore(entryId: entryId, playId: plays[0].id, score: 8)))
    _ = try bridge.update(
      .session(.updateEntryScore(entryId: entryId, playId: plays[1].id, score: 5)))

    let entry = try XCTUnwrap(try bridge.view().summary?.entries.first)
    XCTAssertEqual(entry.plays.map(\.score), [8, 5])
    XCTAssertEqual(entry.scoreSummary, 7, "13 over 2 rounds to 7")
  }

  /// A `playId` that belongs to another entry must be refused, or one row of
  /// the item-complete sheet could write another's mark.
  func testAForeignPlayIdIsRefusedOverTheRealBridge() throws {
    let bridge = LiveBridge()
    let itemId = try exerciseWithTwoVariations(bridge)

    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Clair de Lune", kind: .piece, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let pieceId = try XCTUnwrap(
      try bridge.view().items.first(where: { $0.itemType == .piece })?.id)

    _ = try bridge.update(.session(.startBuilding))
    _ = try bridge.update(.session(.addToSetlist(itemId: itemId)))
    _ = try bridge.update(.session(.addToSetlist(itemId: pieceId)))
    _ = try bridge.update(.session(.startSession(now: "2026-09-01T10:00:00Z")))
    _ = try bridge.update(.session(.nextItem(now: "2026-09-01T10:05:00Z")))
    _ = try bridge.update(.session(.finishSession(now: "2026-09-01T10:10:00Z")))

    let entries = try XCTUnwrap(try bridge.view().summary?.entries)
    let first = try XCTUnwrap(entries.first)
    let foreign = try XCTUnwrap(entries.last?.plays.first?.id)

    _ = try bridge.update(
      .session(.updateEntryScore(entryId: first.id, playId: foreign, score: 9)))

    let after = try XCTUnwrap(try bridge.view().summary?.entries.first)
    XCTAssertNil(after.plays.first?.score, "the foreign play id wrote nothing")
    XCTAssertNotNil(try bridge.view().error, "and the refusal is surfaced")
  }
}
