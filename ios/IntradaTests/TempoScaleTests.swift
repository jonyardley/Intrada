import SharedTypes
import XCTest

@testable import Intrada

@MainActor
final class TempoScaleTests: XCTestCase {
  func testClampWithinRangeIsUnchanged() {
    XCTAssertEqual(TempoScale.clamp(96), 96)
    XCTAssertEqual(TempoScale.clamp(TempoScale.range.lowerBound), 40)
    XCTAssertEqual(TempoScale.clamp(TempoScale.range.upperBound), 208)
  }

  func testClampBelowRangeSnapsToLowerBound() {
    XCTAssertEqual(TempoScale.clamp(30), 40, "a Grave target below the UI range clamps up")
  }

  func testClampAboveRangeSnapsToUpperBound() {
    XCTAssertEqual(TempoScale.clamp(220), 208, "a Presto target above the UI range clamps down")
  }

  func testIncrementFromOutOfRangeMovesTowardRangeNotAway() {
    XCTAssertEqual(TempoScale.stepped(from: 30, by: 2), 40)
  }

  func testDecrementFromOutOfRangeMovesTowardRangeNotAway() {
    XCTAssertEqual(TempoScale.stepped(from: 220, by: -2), 208)
  }

  func testStepWithinRangeMovesByStep() {
    XCTAssertEqual(TempoScale.stepped(from: 96, by: 2), 98)
    XCTAssertEqual(TempoScale.stepped(from: 96, by: -2), 94)
  }

  func testStepClampsAtTheBoundary() {
    XCTAssertEqual(TempoScale.stepped(from: 208, by: 2), 208)
    XCTAssertEqual(TempoScale.stepped(from: 40, by: -2), 40)
  }
}

/// The shell half of the tempo evidence contract (#1420): if `userSet` ever
/// stops tracking the stepper, every tempo becomes unevidenced and the trend
/// goes silently empty — the #846 failure mode with no other guard on it.
@MainActor
final class TrackedTempoTests: XCTestCase {
  func testAPreFillIsNotUserSet() {
    XCTAssertFalse(
      TrackedTempo(startingBpm: 96).userSet,
      "the sheet opening at a pre-filled number is not the user setting one")
  }

  func testSettingMarksItUserSet() {
    var tempo = TrackedTempo(startingBpm: 96)
    tempo.set(120)
    XCTAssertEqual(tempo.bpm, 120)
    XCTAssertTrue(tempo.userSet)
  }

  func testSettingBackToTheStartingValueStillCounts() {
    var tempo = TrackedTempo(startingBpm: 96)
    tempo.set(98)
    tempo.set(96)
    XCTAssertTrue(
      tempo.userSet, "stepping up and back is still the user considering the number")
  }

  func testAnOutOfRangeStartClampsWithoutCountingAsUserSet() {
    let tempo = TrackedTempo(startingBpm: 400)
    XCTAssertEqual(tempo.bpm, TempoScale.range.upperBound)
    XCTAssertFalse(tempo.userSet, "clamping is the app tidying up, not the user choosing")
  }
}

@MainActor
final class AddStepsSheetTests: XCTestCase {
  func testEmptyArrayTrimsToEmpty() {
    XCTAssertEqual(AddStepsSheet.trimmedLabels([]), [])
  }

  func testAllWhitespaceRowsAreDropped() {
    XCTAssertEqual(AddStepsSheet.trimmedLabels(["", "  ", "\n"]), [])
  }

  func testMixedBlankAndPopulatedRowsKeepsOnlyPopulated() {
    XCTAssertEqual(AddStepsSheet.trimmedLabels(["C", "", "G", "  "]), ["C", "G"])
  }

  func testLeadingAndTrailingWhitespaceIsTrimmed() {
    XCTAssertEqual(AddStepsSheet.trimmedLabels(["  C  ", " G"]), ["C", "G"])
  }
}
