import XCTest

/// Drives the player's variation picker against the real bridge (#1739): the
/// chip says what is being practised, switching resets the repetition count,
/// and the item-complete sheet then offers a mark per variation. "Major
/// Scales" is the seeded exercise whose variations are deterministic (`C`,
/// `G`, `D`, `A`, `E`; see `app.rs`'s `LoadSampleData` seed).
@MainActor
final class VariationPickerUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  private func startScalesSession() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--seed-sample-data", "--disable-animations"]
    app.launch()

    app.tabBars.buttons["Practice"].tap()
    app.openEmptyBuilder()

    let addRow = app.buttons["Add piece or exercise"]
    XCTAssertTrue(addRow.waitForExistence(timeout: 10), "Add row")
    addRow.tap()

    let scalesCard = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@ AND value == %@", "Major Scales", "Not added")
    ).firstMatch
    XCTAssertTrue(scalesCard.waitForExistence(timeout: 10), "Major Scales card in the add sheet")
    scalesCard.tap()
    app.buttons["Done"].tap()

    let startSession = app.buttons["Start session"]
    XCTAssertTrue(startSession.waitForExistence(timeout: 5), "Start session bar")
    startSession.tap()
    return app
  }

  private func pick(_ app: XCUIApplication, _ label: String) {
    let chip = app.buttons["Variation"]
    XCTAssertTrue(chip.waitForExistence(timeout: 10), "the variation chip on the player")
    chip.tap()

    let row = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH %@", "\(label),")
    ).firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5), "\(label) row in the picker")
    row.tap()
  }

  private func tapPill(_ selector: XCUIElement, _ value: Int) {
    selector.coordinate(
      withNormalizedOffset: CGVector(dx: (Double(value) - 0.5) / 10, dy: 0.5)
    ).tap()
  }

  func testSwitchingVariationRenamesTheChipAndRestartsTheCount() {
    let app = startScalesSession()

    let chip = app.buttons["Variation"]
    XCTAssertTrue(chip.waitForExistence(timeout: 10), "an exercise with variations shows the chip")
    XCTAssertEqual(
      chip.value as? String, "none picked",
      "nothing was planned in the builder, so the chip invites a pick")

    pick(app, "C")
    XCTAssertEqual(chip.value as? String, "C", "the chip names the variation now being practised")

    let repetitions = app.otherElements["Repetitions"]
    XCTAssertTrue(repetitions.waitForExistence(timeout: 5), "the repetition counter")
    app.buttons["Got it"].tap()
    app.buttons["Got it"].tap()
    XCTAssertEqual(
      repetitions.value as? String, "2 of 10, 8 to go", "two repetitions banked against C")

    pick(app, "G")
    XCTAssertEqual(chip.value as? String, "G", "the chip follows the switch")
    XCTAssertEqual(
      repetitions.value as? String, "0 of 10",
      "the count starts again for G rather than carrying C's total")

    app.abandonSession()
  }

  func testTheItemCompleteSheetOffersAMarkPerVariation() {
    let app = startScalesSession()

    pick(app, "C")
    app.buttons["Got it"].tap()
    pick(app, "G")
    app.buttons["Got it"].tap()

    let finish = app.buttons["Finish session"]
    XCTAssertTrue(finish.waitForExistence(timeout: 5), "the transport's finish button")
    finish.tap()

    let markC = app.otherElements["Mark for C"]
    XCTAssertTrue(
      markC.waitForExistence(timeout: 10), "the stretch played in C has its own mark")
    let markG = app.otherElements["Mark for G"]
    XCTAssertTrue(markG.exists, "and so does the stretch played in G")

    // Two different marks, so one write cannot satisfy both, then save: the
    // sheet's marks only reach the core once the item is completed, which is
    // the path a "Skip rating" test never covers. ScoreSelector hides its ten
    // pills behind one accessibility element, so the taps go by position:
    // pill N's centre sits at (N - 0.5) / 10 across the row.
    tapPill(markC, 7)
    tapPill(markG, 3)

    app.buttons["Save & continue"].tap()

    // The summary is the core's answer: each variation kept the mark it was
    // given, rather than one overwriting the other.
    let summaryC = app.otherElements["Mark for Major Scales, C"]
    XCTAssertTrue(
      summaryC.waitForExistence(timeout: 10), "the summary marks each variation separately")
    XCTAssertEqual(summaryC.value as? String, "7 of 10", "C kept the seven it was given")
    XCTAssertEqual(
      app.otherElements["Mark for Major Scales, G"].value as? String, "3 of 10",
      "and G kept its three rather than C's seven")

    app.discardSummary()
  }
}
