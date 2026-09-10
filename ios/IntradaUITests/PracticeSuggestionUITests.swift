import XCTest

/// The Up next suggestion's own two escape hatches: opening the builder in one
/// tap when you say you'd rather build your own (#1617), and coming back to
/// the suggestion afterwards rather than losing it for the app run (#1618).
@MainActor
final class PracticeSuggestionUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  private func launchSeeded() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--seed-sample-data", "--disable-animations"]
    app.launch()
    return app
  }

  func testBuildOwnInsteadOpensBuilderInOneTap() {
    let app = launchSeeded()
    app.tabBars.buttons["Practice"].tap()

    let buildOwn = app.buttons["Build my own instead"]
    XCTAssertTrue(buildOwn.waitForExistence(timeout: 10), "Up next hero's secondary action")
    buildOwn.tap()

    XCTAssertTrue(
      app.buttons["Add piece or exercise"].waitForExistence(timeout: 10),
      "one tap lands in the builder, with no second tap on Start practising")
  }

  func testSuggestionCanBeRestoredWithoutRelaunching() {
    let app = launchSeeded()
    app.tabBars.buttons["Practice"].tap()

    let buildOwn = app.buttons["Build my own instead"]
    XCTAssertTrue(buildOwn.waitForExistence(timeout: 10), "Up next hero's secondary action")
    buildOwn.tap()
    XCTAssertTrue(
      app.buttons["Add piece or exercise"].waitForExistence(timeout: 10), "in the builder")

    let cancel = app.buttons["Cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 10), "the builder's Cancel button")
    cancel.tap()

    let restore = app.buttons["Show suggestion"]
    XCTAssertTrue(restore.waitForExistence(timeout: 10), "a way back on the ordinary screen")
    restore.tap()

    XCTAssertTrue(
      app.buttons["Build my own instead"].waitForExistence(timeout: 10),
      "the suggestion is back without relaunching")
  }
}
