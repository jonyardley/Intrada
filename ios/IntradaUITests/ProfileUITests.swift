import XCTest

/// The profile round trip a musician makes (#1692): in from the Practice
/// header, edit, save, read the values back, and find them again after the
/// app is relaunched. Launched without seed data on purpose: seed mode skips
/// persistence, and the relaunch is the point.
@MainActor
final class ProfileUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  func testEditSaveAndRelaunchKeepTheProfile() {
    let app = XCUIApplication()
    app.launchArguments = ["--disable-animations", "--reset-profile"]
    app.launch()

    app.tabBars.buttons["Practice"].tap()
    let badge = app.buttons["Profile"]
    XCTAssertTrue(badge.waitForExistence(timeout: 10), "the badge in the Practice header")
    badge.tap()

    let edit = app.buttons["Edit"]
    XCTAssertTrue(edit.waitForExistence(timeout: 5), "the profile screen's Edit")
    XCTAssertTrue(app.staticTexts["Add a name"].exists, "empty profile prompts for a name")
    edit.tap()

    // A SwiftUI TextField exposes its placeholder as `identifier`; the
    // autocomplete field carries its label instead.
    let name = app.textFields["Your name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5), "the name field, by its placeholder")
    name.tap()
    name.typeText("Jon")
    let instrument = app.textFields["Instrument"]
    instrument.tap()
    instrument.typeText("Cel")
    let suggestion = app.buttons["Cello"]
    XCTAssertTrue(suggestion.waitForExistence(timeout: 5), "the instrument suggestion")
    suggestion.tap()
    app.buttons["Coral"].tap()
    app.buttons["Save"].tap()

    XCTAssertTrue(app.staticTexts["Jon"].waitForExistence(timeout: 5), "the saved name")
    XCTAssertTrue(app.staticTexts["Cello"].exists, "the saved instrument")
    XCTAssertTrue(app.highlighterRow("Coral").exists, "the saved highlighter")

    // A refused save keeps the sheet open with the reason, and Cancel drops it.
    edit.tap()
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    name.tap()
    name.typeText(String(repeating: "x", count: 100))
    app.buttons["Save"].tap()
    let banner = app.staticTexts["Name must be 100 characters or fewer"]
    XCTAssertTrue(banner.waitForExistence(timeout: 5), "the core's refusal shows inline")
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.staticTexts["Jon"].waitForExistence(timeout: 5), "the saved name stands")

    app.terminate()
    app.launchArguments = ["--disable-animations"]
    app.launch()
    app.tabBars.buttons["Practice"].tap()
    XCTAssertTrue(
      app.descendants(matching: .any).matching(
        NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", ", Jon", "No sessions yet")
      ).firstMatch.waitForExistence(timeout: 10),
      "the Practice header greets by name after a relaunch")
    app.buttons["Profile"].tap()
    XCTAssertTrue(app.staticTexts["Jon"].waitForExistence(timeout: 5), "the name survived")
    XCTAssertTrue(app.staticTexts["Cello"].exists, "the instrument survived")
    XCTAssertTrue(app.highlighterRow("Coral").exists, "the highlighter survived")
  }
}

extension XCUIApplication {
  /// The profile's highlighter row reads as one element, "Highlighter, Coral".
  fileprivate func highlighterRow(_ colour: String) -> XCUIElement {
    descendants(matching: .any).matching(
      NSPredicate(format: "label == %@", "Highlighter, \(colour)")
    ).firstMatch
  }
}
