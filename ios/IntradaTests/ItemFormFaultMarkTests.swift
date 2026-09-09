import Foundation
import SharedTypes
import Testing

@testable import Intrada

/// Where the add form points after a refused save (#1595). The core decides
/// where the fault is; this is only about how long the form keeps pointing.
@MainActor
struct ItemFormFaultMarkTests {
  private func marked(_ target: FormErrorTarget, staging: [StagedExercise] = [])
    -> ItemFormModel
  {
    let form = ItemFormModel(kind: .piece)
    form.title = "Autumn Leaves"
    form.composer = "Joseph Kosma"
    form.stagedExercises = staging
    form.errorTarget = target
    return form
  }

  private func twoRows() -> [StagedExercise] {
    [
      .existing(id: "ex-1", title: "Shell voicings", meta: "C major"),
      .draft(id: UUID(), title: "   ", key: "", modality: nil, bpm: ""),
    ]
  }

  @Test func onlyTheNamedFieldIsMarked() {
    let form = marked(.piece(field: .composer))

    #expect(form.faults(.composer))
    #expect(!form.faults(.title))
    #expect(!form.faultsChart)
  }

  @Test func bothTempoFieldsCarryOneTempoFault() {
    let form = marked(.piece(field: .tempo))

    #expect(form.faults(.tempo))
    #expect(!form.faults(.notes))
  }

  @Test func typingInTheMarkedFieldClearsIt() {
    let form = marked(.piece(field: .composer))

    form.composer = "Kosma"

    #expect(!form.faults(.composer))
    #expect(form.errorTarget == nil)
  }

  @Test func typingElsewhereLeavesTheMarkWhereItIs() {
    let form = marked(.piece(field: .composer))

    form.title = "Autumn Leaves "
    form.notes = "From the lesson"
    form.tags = ["standards"]

    #expect(form.faults(.composer), "the composer is still the field at fault")
  }

  @Test func editingTheChartClearsAChartMarkAndOnlyThat() {
    let barMarked = marked(.chartBar(barNumber: 2, token: "Hxyz"))
    #expect(barMarked.faultsChart)
    #expect(barMarked.faultedBarNumber == 2)

    barMarked.chartText = "| Cm7 | F7 |"
    #expect(!barMarked.faultsChart)

    let fieldMarked = marked(.piece(field: .title))
    fieldMarked.chartText = "| Cm7 |"
    #expect(fieldMarked.faults(.title), "a chart edit says nothing about the title")
  }

  @Test func awholeChartFaultNamesNoBar() {
    let form = marked(.chart)

    #expect(form.faultsChart)
    #expect(form.faultedBarNumber == nil, "prose with no bars stops at no bar")
  }

  @Test func onlyTheNamedRowIsMarked() {
    let form = marked(.exercise(index: 1, field: .title), staging: twoRows())

    #expect(!form.faults(row: 0))
    #expect(form.faults(row: 1))
    #expect(form.faultedField(row: 1) == .title)
    #expect(form.faultedField(row: 0) == nil)
  }

  @Test func changingTheStagedListDropsTheRowMark() {
    let form = marked(.exercise(index: 1, field: .title), staging: twoRows())
    #expect(form.faults(row: 1))

    form.stagedExercises.removeAll { $0.existingId == "ex-1" }

    #expect(
      form.errorTarget == nil,
      "removing a row renumbers the rest, so a position the core gave is no longer that row")
  }

  @Test func aChosenRowIsMarkedWithNoFieldInside() {
    let form = marked(
      .exercise(index: 0, field: nil),
      staging: [.existing(id: "gone", title: "Shell voicings", meta: nil)])

    #expect(form.faults(row: 0))
    #expect(form.faultedField(row: 0) == nil, "nothing inside a chosen row can be marked")
  }
}
