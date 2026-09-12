import XCTest

/// Real-device UITest for C4 step management (#1083): rename and remove a
/// step, driven against "Major Scales" — the seeded exercise whose demo
/// ladder is deterministic (`C`, `G`, `D`, `A`, `E`, in that order; see
/// `app.rs`'s `LoadSampleData` seed).
///
/// Drag reorder is deliberately not covered here: `.draggable`/
/// `.dropDestination` ride the system Drag & Drop API, which XCUITest can't
/// reliably script a drop through in the Simulator (unlike a List's
/// `onMove` long-press-drag, which `SessionBuilderUITests` automates
/// successfully). Reorder-by-relabeling itself is fully covered by the
/// core's `set_variants_reorder_preserves_ids_by_label` test (id/history
/// preserved, position updated); only the gesture is untested here.
@MainActor
final class StepManagementUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  private func openScalesSteps() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--seed-sample-data", "--disable-animations"]
    app.launch()

    app.tabBars.buttons["Library"].tap()
    let scalesRow = app.buttons.matching(
      NSPredicate(format: "label CONTAINS %@", "Major Scales")
    ).firstMatch
    XCTAssertTrue(scalesRow.waitForExistence(timeout: 10), "Major Scales library row")
    scalesRow.tap()

    let editButton = app.buttons["Edit steps"]
    XCTAssertTrue(editButton.waitForExistence(timeout: 10), "Steps section with Edit button")
    editButton.tap()
    return app
  }

  private func stepField(_ app: XCUIApplication, value: String) -> XCUIElement {
    app.textFields.matching(NSPredicate(format: "value == %@", value)).firstMatch
  }

  func testRenameStepPersistsAndLeavesOthersUntouched() {
    let app = openScalesSteps()

    let eField = stepField(app, value: "E")
    XCTAssertTrue(eField.waitForExistence(timeout: 5), "E step field")
    eField.tap()
    // One typeText call: eField is a live query on `value == "E"`, so a
    // second call after a separate delete step lands can no longer
    // re-resolve it, since the value has already changed (#1642).
    eField.typeText(XCUIKeyboardKey.delete.rawValue + "Fa\n")

    app.buttons["Done editing steps"].tap()

    // Back in read mode: the renamed step shows, "E" is gone, others intact.
    XCTAssertTrue(
      app.staticTexts["Fa"].waitForExistence(timeout: 5), "renamed step reads back as Fa")
    XCTAssertFalse(app.staticTexts["E"].exists, "old label gone")
    XCTAssertTrue(app.staticTexts["C"].exists, "untouched step still present")
    XCTAssertTrue(app.staticTexts["G"].exists, "untouched step still present")
  }

  func testRemoveStepArchivesIt() {
    let app = openScalesSteps()

    let removeA = app.buttons["Remove A from steps"]
    XCTAssertTrue(removeA.waitForExistence(timeout: 5), "remove control for A")
    removeA.tap()

    XCTAssertFalse(
      app.buttons["Remove A from steps"].waitForExistence(timeout: 3), "A row gone from edit list")

    app.buttons["Done editing steps"].tap()
    XCTAssertFalse(app.staticTexts["A"].exists, "removed step no longer shown")
    XCTAssertTrue(app.staticTexts["C"].exists, "other steps still present")
  }
}
