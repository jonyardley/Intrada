import Foundation
import SharedTypes
import Testing

@testable import Intrada

/// Covers the Swift-side plumbing in `LibraryItemView+PickerSort.swift`:
/// field mapping onto `PickerCandidateArg`, the sort-type mapping onto
/// `PickerSortArg`, and reordering `available` by the returned ids. The
/// comparator and the search predicate themselves are tested in Rust
/// (`sort_and_filter_candidates`).
struct LibraryItemPickerSortTests {
  private static func exercise(
    id: String, title: String = "Hanon No. 1", subtitle: String = "Charles-Louis",
    notes: String? = "left hand only", tags: [String] = ["warm-up"], createdAt: String = "",
    lastPractised: String? = nil
  ) -> LibraryItemView {
    var item = LibraryItemView.previewExercise
    item.id = id
    item.title = title
    item.subtitle = subtitle
    item.notes = notes
    item.tags = tags
    item.createdAt = createdAt
    item.practice = lastPractised.map { .fixture(lastPracticedAt: $0) }
    return item
  }

  @Test("titles sort case-insensitively, ascending and descending")
  func sortsByTitle() {
    let items = [
      Self.exercise(id: "a", title: "Scales", createdAt: "2026-01-01"),
      Self.exercise(id: "b", title: "arpeggios", createdAt: "2026-01-02"),
    ]

    #expect(
      items.sortedAndFiltered(
        by: LibrarySort(field: .title, direction: .ascending), search: ""
      ).map(\.id) == ["b", "a"])
    #expect(
      items.sortedAndFiltered(
        by: LibrarySort(field: .title, direction: .descending), search: ""
      ).map(\.id) == ["a", "b"])
  }

  @Test("date added sorts ascending and descending, so createdAt reaches the bridge call")
  func sortsByDateAdded() {
    let items = [
      Self.exercise(id: "a", createdAt: "2026-01-03"),
      Self.exercise(id: "b", createdAt: "2026-01-01"),
      Self.exercise(id: "c", createdAt: "2026-01-02"),
    ]

    #expect(
      items.sortedAndFiltered(
        by: LibrarySort(field: .dateAdded, direction: .ascending), search: ""
      ).map(\.id) == ["b", "c", "a"])
    #expect(
      items.sortedAndFiltered(
        by: LibrarySort(field: .dateAdded, direction: .descending), search: ""
      ).map(\.id) == ["a", "c", "b"])
  }

  @Test("last practiced sorts through the practice summary field")
  func sortsByLastPracticed() {
    let items = [
      Self.exercise(id: "a", createdAt: "2026-01-01", lastPractised: "2026-08-01"),
      Self.exercise(id: "b", createdAt: "2026-01-02"),
    ]

    let result = items.sortedAndFiltered(
      by: LibrarySort(field: .lastPracticed, direction: .ascending), search: "")

    #expect(result.map(\.id) == ["b", "a"], "never practised sorts before a practised item")
  }

  @Test(
    "words a musician would type find the exercise, across every searchable field",
    arguments: ["No. 1", "Charles-Louis", "left hand", "warm-up"])
  func searchMatchesEachField(text: String) {
    let items = [Self.exercise(id: "a")]

    let result = items.sortedAndFiltered(
      by: LibrarySort(field: .title, direction: .ascending), search: text)

    #expect(result.map(\.id) == ["a"])
  }

  @Test("a word in none of the searchable fields does not match")
  func searchMissesWhatIsNotThere() {
    let items = [Self.exercise(id: "a")]

    let result = items.sortedAndFiltered(
      by: LibrarySort(field: .title, direction: .ascending), search: "Debussy")

    #expect(result.isEmpty)
  }

  @Test("whitespace-only search is no search")
  func emptySearchMatchesEverything() {
    let items = [Self.exercise(id: "a"), Self.exercise(id: "b", title: "Scales")]

    let result = items.sortedAndFiltered(
      by: LibrarySort(field: .title, direction: .ascending), search: "   ")

    #expect(result.count == 2)
  }
}
