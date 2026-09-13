import XCTest

/// The bar line appears only while the click sounds, the sheet it opens changes
/// which beats sound, and the metre chosen there reaches the hand-off. The
/// engine tests cover the grid; this covers the wiring from the row to the
/// sheet and on to the reflection.
///
/// One launch, not one per assertion: the UI tier is a merge gate, and each
/// pass through the builder costs minutes on CI (#1207's UI half caps at 20).
@MainActor
final class ClickBarUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  func testTheBarFollowsTheSheetAndTheMetreReachesTheReflection() {
    let app = XCUIApplication()
    app.launchArguments = ["--seed-sample-data", "--disable-animations"]
    app.launch()
    app.startOneItemSession()

    let start = app.buttons["Start the metronome"]
    XCTAssertTrue(start.waitForExistence(timeout: 10), "the click row is up")
    XCTAssertFalse(app.buttons["Bar"].exists, "no bar line while silent")
    start.tap()

    let bar = app.buttons["Bar"]
    XCTAssertTrue(bar.waitForExistence(timeout: 5), "the bar line appears while sounding")
    XCTAssertEqual(bar.value as? String, "4 crotchet beats, metronome on every beat")

    // A pattern changes which beats sound, and nothing else.
    bar.tap()
    let downbeat = app.buttons["Downbeat"]
    XCTAssertTrue(downbeat.waitForExistence(timeout: 5), "the click sheet opens from the bar line")
    downbeat.tap()
    app.buttons["Done"].tap()
    XCTAssertTrue(bar.waitForExistence(timeout: 5))
    XCTAssertEqual(bar.value as? String, "4 crotchet beats, metronome on beat 1")

    // A new metre reads in its own unit and starts sounding every beat again.
    bar.tap()
    let compound = app.buttons["6/8"]
    XCTAssertTrue(compound.waitForExistence(timeout: 5), "the metre presets are offered")
    compound.tap()
    app.buttons["Done"].tap()
    XCTAssertTrue(bar.waitForExistence(timeout: 5))
    XCTAssertEqual(bar.value as? String, "6 quaver beats, metronome on every beat")

    app.buttons["Stop the metronome"].tap()
    XCTAssertFalse(
      app.buttons["Bar"].waitForExistence(timeout: 2), "the bar line leaves with the click")

    // The quaver metre has to survive the hand-off, or the reflection asks for
    // a crotchet tempo the player never played (#1499).
    app.buttons["Finish session"].tap()
    let achieved = app.descendants(matching: .any).matching(identifier: "Achieved tempo").firstMatch
    XCTAssertTrue(achieved.waitForExistence(timeout: 5), "the reflection sheet is up")
    XCTAssertTrue(
      (achieved.value as? String)?.hasSuffix("quaver beats per minute") == true,
      "the stepper counts in the unit the click counted, not crotchets: "
        + "\(achieved.value as? String ?? "no value")")

    app.buttons["Skip rating"].tap()
    app.discardSummary()
  }
}
