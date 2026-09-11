import XCTest

/// Real-app UITest for #1595: a create the core refuses keeps the form open
/// with the banner on it, which is the whole reason marking the fault is worth
/// anything. Driven through the chart, since `ChordChartEditSheet` hands its
/// text back unparsed on the create path and the refusal lands on Add.
@MainActor
final class CreateFaultUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  func testARefusedOnePassCreateKeepsTheFormOpenAndNamesTheFault() {
    let app = XCUIApplication()
    app.launchArguments = ["--seed-sample-data", "--disable-animations"]
    app.launch()

    app.tabBars.buttons["Library"].tap()
    let add = app.buttons["Add item"]
    XCTAssertTrue(add.waitForExistence(timeout: 10), "Library's add button")
    add.tap()

    // The chart first, while nothing has raised the keyboard: with it up, the
    // section rows sit under it and a tap never reaches them.
    let chartRow = app.buttons.matching(NSPredicate(format: "label == %@", "Chord chart"))
    XCTAssertTrue(chartRow.firstMatch.waitForExistence(timeout: 10), "the chord chart row")
    let tappable = chartRow.allElementsBoundByIndex.first { $0.isHittable }
    XCTAssertNotNil(tappable, "one of the chord chart rows takes a tap")
    tappable?.tap()

    XCTAssertTrue(
      app.navigationBars["Chord chart"].waitForExistence(timeout: 5), "the chart sheet opened")
    let editor = app.textViews["Chord chart text"]
    XCTAssertTrue(editor.waitForExistence(timeout: 5), "the chart editor")
    editor.tap()
    editor.typeText("| Dm7 | G7 |")
    app.buttons["Save"].firstMatch.tap()

    let title = app.textFields["Required"].firstMatch
    XCTAssertTrue(title.waitForExistence(timeout: 5), "the title field, by its placeholder")
    title.tap()
    title.typeText("Kettle of fish")

    // An over-long composer, so the piece itself is what the core refuses. The
    // create carries a chart, so it goes through the one-pass event, not a
    // plain add.
    let composer = app.textFields["Composer"].firstMatch
    XCTAssertTrue(composer.waitForExistence(timeout: 5), "the composer field")
    composer.tap()
    composer.typeText(String(repeating: "x", count: 201))
    app.buttons["Add"].firstMatch.tap()

    XCTAssertTrue(
      app.staticTexts["Composer must be between 1 and 200 characters"].waitForExistence(
        timeout: 5),
      "the core's own sentence, on the form rather than behind it")
    XCTAssertTrue(
      app.navigationBars["New Piece"].exists,
      "a refused create leaves everything staged on screen, chart included")

    app.buttons["Cancel"].firstMatch.tap()
    XCTAssertFalse(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Kettle of fish"))
        .firstMatch.waitForExistence(timeout: 3),
      "nothing was written, so the library is as it was")
  }
}
