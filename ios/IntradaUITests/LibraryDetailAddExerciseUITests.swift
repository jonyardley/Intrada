import XCTest

/// Exercises #1616 on the piece detail screen: the same single "Add exercise"
/// action, where creating and selecting both land linked to the piece.
@MainActor
final class LibraryDetailAddExerciseUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  /// A covered stacked sheet stays in the tree but not hittable, so a shared
  /// label (two "Required" fields, two "Done" buttons) needs this to disambiguate.
  private func hittable(_ query: XCUIElementQuery, timeout: TimeInterval = 5) -> XCUIElement? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if let match = query.allElementsBoundByIndex.first(where: \.isHittable) {
        return match
      }
      usleep(100_000)
    } while Date() < deadline
    return nil
  }

  func testCreatingAndSelectingInThePickerBothLinkToThePiece() {
    let app = XCUIApplication()
    app.launchArguments = ["--seed-sample-data", "--disable-animations"]
    app.launch()

    app.tabBars.buttons["Library"].tap()
    let clairRow = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "Clair de Lune")
    ).firstMatch
    XCTAssertTrue(clairRow.waitForExistence(timeout: 10), "Clair library row")
    clairRow.tap()

    let addExercise = app.buttons["Add an exercise for this piece"]
    XCTAssertTrue(addExercise.waitForExistence(timeout: 10), "the single Add exercise action")
    addExercise.tap()

    let createTrigger = app.buttons["Create an exercise"]
    XCTAssertTrue(createTrigger.waitForExistence(timeout: 5), "create-inline trigger")
    createTrigger.tap()

    let requiredFields = app.textFields.matching(identifier: "Required")
    let draftTitle = hittable(requiredFields)
    XCTAssertNotNil(draftTitle, "the draft exercise's title field")
    draftTitle?.tap()
    draftTitle?.typeText("Chromatic run")
    let doneButtons = app.buttons.matching(NSPredicate(format: "label == %@", "Done"))
    hittable(doneButtons)?.tap()

    XCTAssertTrue(
      app.staticTexts["Chromatic run"].waitForExistence(timeout: 5),
      "the fresh draft joins the picker's own list")

    let hanon = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Hanon No. 1"))
      .firstMatch
    XCTAssertTrue(hanon.waitForExistence(timeout: 5), "Hanon in the picker's existing list")
    hanon.tap()

    app.buttons["Done"].firstMatch.tap()

    // Links immediately on Done, since the piece already exists (#1431).
    XCTAssertTrue(
      app.staticTexts["Chromatic run"].waitForExistence(timeout: 5),
      "the created exercise survives the picker closing and reads as linked")
    XCTAssertTrue(
      app.staticTexts["Hanon No. 1"].waitForExistence(timeout: 5),
      "the selected exercise survives the picker closing and reads as linked")
  }
}
