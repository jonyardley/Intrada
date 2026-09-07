import XCTest

/// Real-bridge UITest for opening a past session from Practice history (#1371).
/// The tap is wired with `onTapGesture` driving `navigationDestination(item:)`
/// rather than a `NavigationLink`, because a link tinted the whole screen a
/// shade lighter, so nothing but a running app proves the push still happens.
@MainActor
final class SessionHistoryUITests: XCTestCase {
  override func setUp() { continueAfterFailure = false }

  /// One test, not two: seeded data carries no finished sessions, so reaching
  /// the thing under test costs a whole session played through the builder and
  /// the player. A second case would double that for one more assertion.
  func testTappingASessionCardOpensTheRecordOfWhatWasPlayed() {
    let app = XCUIApplication()
    app.launchArguments = ["--seed-sample-data", "--disable-animations"]
    app.launch()

    app.startOneItemSession()
    app.endSessionEarly()
    app.saveSummary()

    let card = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "1 piece")
    ).firstMatch
    XCTAssertTrue(card.waitForExistence(timeout: 10), "a saved session card in history")
    card.tap()

    // Assert on the detail screen's own content: a card that merely vanished
    // would also satisfy "the card is gone".
    XCTAssertTrue(
      app.staticTexts["What you played"].waitForExistence(timeout: 10),
      "the session detail screen is up")
    let item = app.staticTexts.matching(
      NSPredicate(format: "label CONTAINS %@", "Clair de Lune")
    ).firstMatch
    XCTAssertTrue(item.exists, "the item played appears in the record")
  }
}
