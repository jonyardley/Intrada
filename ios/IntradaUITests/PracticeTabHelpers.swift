import XCTest

extension XCUIApplication {
  /// The seeded library has a piece with a related exercise, so the Practice
  /// hero is the Up next suggestion (#1082); "Build my own instead" opens the
  /// blank builder directly in one tap (#1617).
  @MainActor
  func openEmptyBuilder(file: StaticString = #filePath, line: UInt = #line) {
    let buildOwn = buttons["Build my own instead"]
    XCTAssertTrue(
      buildOwn.waitForExistence(timeout: 10), "Up next hero's secondary action", file: file,
      line: line)
    buildOwn.tap()
  }

  /// The shortest route to the focus player: one seeded library item in a
  /// session, started. Two suites drive it, so it lives here.
  @MainActor
  func startOneItemSession(file: StaticString = #filePath, line: UInt = #line) {
    tabBars.buttons["Practice"].tap()
    openEmptyBuilder(file: file, line: line)

    let addRow = buttons["Add piece or exercise"]
    XCTAssertTrue(addRow.waitForExistence(timeout: 5), "Add row", file: file, line: line)
    addRow.tap()
    let notAdded = buttons.matching(NSPredicate(format: "value == %@", "Not added"))
    XCTAssertTrue(
      notAdded.firstMatch.waitForExistence(timeout: 5), "Library cards in sheet", file: file,
      line: line)
    notAdded.firstMatch.tap()
    buttons["Done"].tap()

    let startSession = buttons["Start session"]
    XCTAssertTrue(
      startSession.waitForExistence(timeout: 5), "Start session bar", file: file, line: line)
    startSession.tap()
  }

  /// Abandons the running session so the next test starts from a clean
  /// container: an in-progress session outlives the app in UserDefaults.
  @MainActor
  func abandonSession() {
    buttons["Session options"].tap()
    let end = buttons["End session early"]
    if end.waitForExistence(timeout: 3) {
      end.tap()
      let discard = buttons["Discard"]
      if discard.waitForExistence(timeout: 5) { discard.tap() }
    }
  }

  /// Same job for a session that reached the summary: only `SaveSession` and
  /// `DiscardSession` clear the in-progress blob, and reaching the summary
  /// clears nothing.
  @MainActor
  func discardSummary(file: StaticString = #filePath, line: UInt = #line) {
    let discard = buttons["Discard"]
    XCTAssertTrue(
      discard.waitForExistence(timeout: 10), "the summary is up", file: file, line: line)
    discard.tap()
    let confirm = alerts.buttons["Discard"]
    XCTAssertTrue(
      confirm.waitForExistence(timeout: 5), "the discard confirmation", file: file, line: line)
    confirm.tap()
  }

  /// Saves a session that reached the summary, which is the only way to leave a
  /// card in Practice history for a test to open (#1371).
  @MainActor
  func saveSummary(file: StaticString = #filePath, line: UInt = #line) {
    let save = buttons["Save session"]
    XCTAssertTrue(save.waitForExistence(timeout: 10), "the summary is up", file: file, line: line)
    save.tap()
  }

  /// Ends a running session early, which lands on the summary.
  @MainActor
  func endSessionEarly(file: StaticString = #filePath, line: UInt = #line) {
    buttons["Session options"].tap()
    let end = buttons["End session early"]
    XCTAssertTrue(
      end.waitForExistence(timeout: 5), "End session early", file: file, line: line)
    end.tap()
  }
}
