import SharedTypes
import SwiftUI

/// iPad-adaptive Library: a sidebar list + a detail pane on regular width; the
/// unchanged push-navigation stack on compact (iPhone). Selection drives the
/// detail pane directly on iPad rather than pushing.
struct LibrarySplitView: View {
  @Environment(Store.self) private var store
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var selectedId: String?

  init() {}

  #if DEBUG
    /// Preview/snapshot seed: render with a detail already selected.
    init(previewSelection: String?) {
      _selectedId = State(initialValue: previewSelection)
    }
  #endif

  private var items: [LibraryItemView] { store.viewModel?.items ?? [] }
  private var selectedItem: LibraryItemView? {
    selectedId.flatMap { id in items.first { $0.id == id } }
  }

  var body: some View {
    if sizeClass == .regular {
      HStack(spacing: 0) {
        NavigationStack { LibraryScreen(selection: $selectedId) }
          .frame(maxWidth: 380)
        // Inset to the safe area so the line starts below the top strip rather
        // than running up behind the tabs, where nothing else has a border
        // (#1682). `PaperBackground` ignores the safe area, which is what lets
        // the columns, and so a plain `Divider`, reach the top of the screen.
        Divider().safeAreaPadding(.top)
        NavigationStack {
          detailColumn
            // Related exercises / pieces push within the detail pane, not the list.
            .navigationDestination(for: String.self) { id in
              if let found = items.first(where: { $0.id == id }) {
                LibraryDetailScreen(item: found)
              }
            }
        }
        .frame(maxWidth: .infinity)
      }
    } else {
      NavigationStack { LibraryScreen() }
    }
  }

  @ViewBuilder private var detailColumn: some View {
    if let selectedItem {
      LibraryDetailScreen(item: selectedItem)
    } else {
      ZStack {
        PaperBackground()
        PlaceholderContent(
          systemImage: "sidebar.left", message: "Select an item to see its details.",
          glyphTint: IntradaColor.inkFainter)
      }
      // With nothing selected there is no title or toolbar to give this
      // column its own nav bar, so it reserves none and the two columns'
      // header rules land at different heights. Force an empty one so both
      // columns still reserve the same top chrome (#1682).
      .toolbar(.visible, for: .navigationBar)
    }
  }
}
