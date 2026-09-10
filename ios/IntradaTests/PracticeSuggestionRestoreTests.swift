import SharedTypes
import Testing

@testable import Intrada

@MainActor
struct PracticeSuggestionRestoreTests {
  @Test("Not dismissed, so there is nothing to bring back")
  func hiddenWhenNotDismissed() throws {
    let viewModel = try #require(Store.previewPracticeSuggestion.viewModel)
    #expect(!PracticeScreen.showsSuggestionRestore(viewModel, dismissed: false))
  }

  @Test("Dismissed but the core has nothing to suggest")
  func hiddenWithoutSuggestion() throws {
    let viewModel = try #require(Store.previewPractice.viewModel)
    #expect(!PracticeScreen.showsSuggestionRestore(viewModel, dismissed: true))
  }

  @Test("No view model at all")
  func hiddenWithNilViewModel() {
    #expect(!PracticeScreen.showsSuggestionRestore(nil, dismissed: true))
  }

  @Test("Dismissed and idle is the state that offers the way back")
  func shownWhenDismissedAndIdle() throws {
    let viewModel = try #require(Store.previewPracticeSuggestion.viewModel)
    #expect(PracticeScreen.showsSuggestionRestore(viewModel, dismissed: true))
  }

  // Building your own is exactly what dismissing led to, so the route must not
  // survive into it (#1618).
  @Test("Anything already under way hides it")
  func hiddenWhileSessionUnderWay() throws {
    let idle = try #require(Store.previewPracticeSuggestion.viewModel)

    var building = idle
    building.buildingSetlist = try #require(Store.previewBuilding.viewModel?.buildingSetlist)
    #expect(!PracticeScreen.showsSuggestionRestore(building, dismissed: true))

    var active = idle
    active.activeSession = try #require(Store.previewActive.viewModel?.activeSession)
    #expect(!PracticeScreen.showsSuggestionRestore(active, dismissed: true))

    var summary = idle
    summary.summary = try #require(Store.previewSummary.viewModel?.summary)
    #expect(!PracticeScreen.showsSuggestionRestore(summary, dismissed: true))
  }
}
