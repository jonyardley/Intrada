import SwiftUI

/// The shared shell every top-level screen is built from. The page title lives
/// in the content, not a UIKit nav bar (the locked *Library — Light* header).
struct ScreenScaffold<Content: View, Trailing: View>: View {
  let title: String
  var subtitle: String?
  var trailing: TrailingAction?
  /// A trailing view of the screen's own (the Practice profile badge, #1692);
  /// it sits where `trailing`'s circular button would.
  let trailingContent: Trailing
  @ViewBuilder var content: Content

  struct TrailingAction {
    let label: String
    var systemImage: String = "plus"
    let action: () -> Void
  }

  init(
    title: String,
    subtitle: String? = nil,
    trailing: TrailingAction? = nil,
    @ViewBuilder content: () -> Content
  ) where Trailing == EmptyView {
    self.title = title
    self.subtitle = subtitle
    self.trailing = trailing
    self.trailingContent = EmptyView()
    self.content = content()
  }

  init(
    title: String,
    subtitle: String? = nil,
    @ViewBuilder trailingContent: () -> Trailing,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.trailing = nil
    self.trailingContent = trailingContent()
    self.content = content()
  }

  var body: some View {
    // The background sizes and the content floats: a ZStack used to size to an
    // un-shrinkable child, and every ancestor then centred it (#1470, #1481).
    PaperBackground()
      .overlay(alignment: .topLeading) {
        VStack(alignment: .leading, spacing: 0) {
          header
          Rectangle()
            .fill(IntradaColor.divider)
            .frame(height: 1)
            .padding(.top, IntradaSpacing.cardCompact)
          content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      // Clamp the floor (avoid sub-readable text) but allow the full accessibility
      // range now that the filter tabs scroll instead of wrapping (#810).
      .dynamicTypeSize(.xSmall ... .accessibility5)
  }

  private var titleText: some View {
    Text(title)
      .font(IntradaFont.pageTitle())
      .foregroundStyle(IntradaColor.ink)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 3) {
        // A swipe behind a wrapped title would land under its last line only.
        ViewThatFits(in: .horizontal) {
          titleText.lineLimit(1).markerSwipe()
          titleText
        }
        if let subtitle {
          Text(subtitle)
            .font(IntradaFont.meta)
            .foregroundStyle(IntradaColor.inkSecondary)
        }
      }
      // Combine only the title block so the trailing action stays its own
      // VoiceOver element rather than being merged into the heading.
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
        subtitle.map { "\(title), \($0.replacingOccurrences(of: " · ", with: ", "))" } ?? title)
      Spacer(minLength: 12)
      if let trailing {
        Button(action: trailing.action) {
          Image(systemName: trailing.systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(IntradaColor.onAccent)
            .frame(width: 30, height: 30)
            .background(IntradaColor.accent, in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(trailing.label)
        // Centre the circular button on the title's baseline rather than
        // letting it hang below it.
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
      }
      trailingContent
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
    }
    .padding(.horizontal, IntradaSpacing.card)
    .padding(.top, IntradaSpacing.controlGap)
  }
}

#if DEBUG
  #Preview {
    ScreenScaffold(
      title: "Library",
      subtitle: "12 items",
      trailing: .init(label: "Add", action: {})
    ) {
      PlaceholderContent(
        systemImage: "books.vertical",
        message: "Pieces and exercises will live here.")
    }
  }
#endif
