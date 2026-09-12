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
    app.launchArguments = ["--disable-animations"]
    app.launch()

    app.tabBars.buttons["Practice"].tap()
    let badge = app.buttons["Profile"]
    XCTAssertTrue(badge.waitForExistence(timeout: 10), "the badge in the Practice header")
    badge.tap()

    let edit = app.buttons["Edit"]
    XCTAssertTrue(edit.waitForExistence(timeout: 5), "the profile screen's Edit")
    XCTAssertTrue(app.staticTexts["Add your name"].exists, "empty profile prompts for a name")
    edit.tap()

    let name = app.textFields["Your name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5), "the name field, by its placeholder")
    name.tap()
    name.typeText("Jon")
    let instrument = app.textFields["Instrument"]
    instrument.tap()
    instrument.typeText("Cello")
    app.buttons["Coral"].tap()
    app.buttons["Save"].tap()

    XCTAssertTrue(app.staticTexts["Jon"].waitForExistence(timeout: 5), "the saved name")
    XCTAssertTrue(app.staticTexts["Cello"].exists, "the saved instrument")
    XCTAssertTrue(app.staticTexts["Coral"].exists, "the saved highlighter")

    app.terminate()
    app.launch()
    app.tabBars.buttons["Practice"].tap()
    XCTAssertTrue(
      app.staticTexts.matching(NSPredicate(format: "label CONTAINS ', Jon · '")).firstMatch
        .waitForExistence(timeout: 10),
      "the Practice subtitle greets by name after a relaunch")
    app.buttons["Profile"].tap()
    XCTAssertTrue(app.staticTexts["Jon"].waitForExistence(timeout: 5), "the name survived")
    XCTAssertTrue(app.staticTexts["Cello"].exists, "the instrument survived")
    XCTAssertTrue(app.staticTexts["Coral"].exists, "the highlighter survived")
  }
}
