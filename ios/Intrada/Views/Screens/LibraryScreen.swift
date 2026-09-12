import SharedTypes
import SwiftUI

struct LibraryScreen: View {
  @Environment(Store.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var adding = false
  // Leading "priorities only" filter: prioritise is a filter, not a section.
  // Shell-side over the core-filtered list, until ListQuery carries a priority
  // dimension (#1003).
  @State private var starFilter = false
  // iPad split mode: when set, rows select into the shared binding (detail pane)
  // instead of pushing a stack. nil on compact — the unchanged push navigation.
  private var selection: Binding<String?>? = nil
  private let previewSearch: String?

  init() { previewSearch = nil }

  init(selection: Binding<String?>) {
    previewSearch = nil
    self.selection = selection
  }

  #if DEBUG
    /// Preview/snapshot seed: render with the search bar already revealed.
    init(previewSearch: String) { self.previewSearch = previewSearch }
  #endif

  private var items: [LibraryItemView] { store.viewModel?.items ?? [] }
  private var displayedItems: [LibraryItemView] {
    starFilter ? items.filter(\.priority) : items
  }

  var body: some View {
    ScreenScaffold(
      title: "Library", subtitle: subtitle,
      trailing: .init(label: "Add item", action: { adding = true })
    ) {
      VStack(spacing: 0) {
        BrowseControlsBar(previewSearch: previewSearch, starFilter: $starFilter)
        content
      }
    }
    // The list draws its own header, so suppress the nav bar here; the
    // detail keeps it for the back chevron. In the split the detail's bar is
    // still there for the star and Edit, so keeping an empty one here gives
    // both columns the same top inset and their header rules line up (#1682).
    .toolbar(selection == nil ? .hidden : .visible, for: .navigationBar)
    // The read belongs to the sheet. `onDismiss`, not the add screen's own
    // `onDisappear`, which the scanner's full-screen cover also triggers.
    .sheet(isPresented: $adding, onDismiss: { store.send(.discardPhotoDraft) }) {
      LibraryAddScreen(defaultKind: store.viewModel?.activeQuery?.itemType ?? .piece)
        .environment(store)
    }
    // Key on the id (not the value) so an edit — which changes the item's hash —
    // doesn't break the pushed destination; the detail re-reads the fresh item.
    .navigationDestination(for: String.self) { id in
      if let found = items.first(where: { $0.id == id }) {
        LibraryDetailScreen(item: found)
      }
    }
  }

  @ViewBuilder private var content: some View {
    if displayedItems.isEmpty {
      PlaceholderContent(
        systemImage: emptyIcon,
        message: emptyMessage)
    } else {
      ScrollView {
        VStack(spacing: IntradaSpacing.cardCompact) {
          ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
            libraryRow(item)
              .fadeUp(min(index, 5))
          }
        }
        .padding(.horizontal, IntradaSpacing.card)
        .padding(.vertical, IntradaSpacing.card)
      }
      .scrollDismissesKeyboard(.interactively)
      .scrollEdgeShadow()
    }
  }

  @ViewBuilder private func libraryRow(_ item: LibraryItemView) -> some View {
    rowLink(item)
      // Prioritise is a filter now, so the row stays clean (meter only); starring
      // moves off the row to a long-press menu here + an explicit toggle on the
      // detail screen. (`.swipeActions` only works inside a `List`.)
      .contextMenu {
        Button {
          toggleStar(item.id)
        } label: {
          Label(
            item.priority ? "Remove from priorities" : "Add to priorities",
            systemImage: item.priority ? "star.slash" : "star")
        }
      }
  }

  @ViewBuilder private func rowLink(_ item: LibraryItemView) -> some View {
    if let selection {
      Button {
        selection.wrappedValue = item.id
      } label: {
        LibraryItemCard(item: item, showsMastery: true)
          .overlay(
            RoundedRectangle(cornerRadius: IntradaRadius.card)
              .stroke(IntradaColor.accent, lineWidth: 2)
              .opacity(selection.wrappedValue == item.id ? 1 : 0))
      }
      .buttonStyle(.plain)
    } else {
      NavigationLink(value: item.id) {
        LibraryItemCard(item: item, showsMastery: true)
      }
      .buttonStyle(.plain)
    }
  }

  // Read the item fresh at tap time — a render-captured value can go stale.
  private func toggleStar(_ id: String) {
    guard let item = store.viewModel?.items.first(where: { $0.id == id }) else { return }
    withAnimation(reduceMotion ? nil : IntradaMotion.standard) {
      store.send(.item(.update(id: id, input: togglePriority(item))))
    }
  }

  // Priority-only update: every optional field is "no change" (nil), priority flips.
  // A failed write surfaces on the global banner, not a silent no-op (#846).
  private func togglePriority(_ item: LibraryItemView) -> UpdateItem {
    UpdateItem(
      title: item.title, kind: item.itemType,
      composer: nil, key: nil, modality: nil, tempo: nil, notes: nil,
      tags: nil, priority: !item.priority)
  }

  private var isSearching: Bool {
    !(store.viewModel?.activeQuery?.text ?? "").isEmpty
  }

  private var emptyIcon: String {
    if starFilter { return "star" }
    return isSearching ? "magnifyingglass" : "books.vertical"
  }

  private var emptyMessage: String {
    if starFilter && !items.isEmpty {
      return "No priorities yet. Swipe a row to add it to priorities."
    }
    if let text = store.viewModel?.activeQuery?.text, !text.isEmpty {
      return "No items match “\(text)”."
    }
    switch LibraryFilter(kind: store.viewModel?.activeQuery?.itemType) {
    case .all: return "Pieces and exercises will live here."
    case .pieces: return "No pieces yet."
    case .exercises: return "No exercises yet."
    }
  }

  private var subtitle: String? {
    guard let vm = store.viewModel else { return nil }
    let parts = [
      count(Int(vm.visiblePieces), "piece"), count(Int(vm.visibleExercises), "exercise"),
    ]
    .compactMap { $0 }
    if parts.isEmpty {
      return (vm.activeQuery == nil) ? "No items yet" : "No matches"
    }
    return parts.joined(separator: " · ")
  }

  private func count(_ n: Int, _ noun: String) -> String? {
    n == 0 ? nil : "\(n) \(noun)\(n == 1 ? "" : "s")"
  }
}

#if DEBUG
  #Preview("Populated") {
    NavigationStack { LibraryScreen() }
      .environment(Store.previewLibraryMastery)
  }

  #Preview("Searching") {
    NavigationStack { LibraryScreen(previewSearch: "clair") }
      .environment(Store.previewLibrarySearching)
  }

  #Preview("Empty") {
    NavigationStack { LibraryScreen() }
      .environment(Store.preview)
  }
#endif
