import XCTest

/// Exercises #1616: the Add a piece screen's single "Add exercise" button,
/// where creating and selecting both land in the same staged list.
@MainActor
final class LibraryAddExerciseUITests: XCTestCase {
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

  func testCreatingAndSelectingInThePickerBothLandInTheStagedList() {
    let app = XCUIApplication()
    app.launchArguments = ["--seed-sample-data", "--disable-animations"]
    app.launch()

    app.tabBars.buttons["Library"].tap()
    let add = app.buttons["Add item"]
    XCTAssertTrue(add.waitForExistence(timeout: 10), "Library's add button")
    add.tap()

    let title = app.textFields["Required"].firstMatch
    XCTAssertTrue(title.waitForExistence(timeout: 5), "the title field, by its placeholder")
    title.tap()
    title.typeText("Nocturne in E flat")

    // FormSectionRow double-reports on this iOS version, so firstMatch disambiguates.
    app.buttons["Related exercises"].firstMatch.tap()
    let addExercise = app.buttons["Add an exercise for this piece"]
    XCTAssertTrue(addExercise.waitForExistence(timeout: 5), "the single Add exercise action")
    addExercise.tap()

    let createTrigger = app.buttons["Create an exercise"]
    XCTAssertTrue(createTrigger.waitForExistence(timeout: 5), "create-inline trigger")
    createTrigger.tap()

    // A SwiftUI TextField exposes its placeholder as `identifier`, not `label`,
    // so this matches the covered field the same way the subscript above does.
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

    XCTAssertTrue(
      app.staticTexts["Chromatic run"].waitForExistence(timeout: 5),
      "the drafted exercise survives the picker closing")
    XCTAssertTrue(
      app.staticTexts["Hanon No. 1"].waitForExistence(timeout: 5),
      "the selected exercise survives the picker closing")
  }
}
