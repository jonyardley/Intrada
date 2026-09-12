import SharedTypes
import SwiftUI

/// The second sheet from the profile's edit card: the instrument's match
/// first, then every icon. Picking the match clears the choice, so the icon
/// follows the instrument again; any other pins it (#1692).
struct InstrumentIconPicker: View {
  let suggested: InstrumentIcon
  @Binding var choice: InstrumentIcon?

  var body: some View {
    BottomSheet(title: "Icon", detents: [.large]) {
      EmptyView()
    } content: {
      ScrollView {
        VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
          if suggested != .other {
            Eyebrow("Matches \(suggested.tileLabel.lowercased())")
            grid(of: [suggested])
              .padding(.bottom, IntradaSpacing.cardCompact)
          }
          Eyebrow("All icons")
          grid(of: InstrumentIcon.all.filter { $0 != suggested })
        }
        .padding(.horizontal, IntradaSpacing.card)
        .padding(.top, IntradaSpacing.controlGap)
        .padding(.bottom, IntradaSpacing.section)
      }
    }
  }

  private var shown: InstrumentIcon { choice ?? suggested }

  private func grid(of icons: [InstrumentIcon]) -> some View {
    LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10
    ) {
      ForEach(icons, id: \.self) { icon in
        tile(icon)
      }
    }
  }

  private func tile(_ icon: InstrumentIcon) -> some View {
    let selected = icon == shown
    return Button {
      choice = icon == suggested ? nil : icon
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      VStack(spacing: 6) {
        InstrumentGlyph(icon: icon, size: IntradaGlyph.bar)
          .foregroundStyle(IntradaColor.ink)
        Text(icon.tileLabel)
          .font(IntradaFont.metaMedium)
          .foregroundStyle(selected ? IntradaColor.ink : IntradaColor.inkSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 84)
      .padding(.horizontal, 4)
      .background(selected ? marker : IntradaColor.cardFill)
      .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.card))
      .overlay(
        RoundedRectangle(cornerRadius: IntradaRadius.card)
          .stroke(selected ? IntradaColor.ink : IntradaColor.hairline, lineWidth: 1)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(icon.accessibilityLabel)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  @Environment(\.marker) private var marker
}

#if DEBUG
  #Preview {
    struct Demo: View {
      @State private var choice: InstrumentIcon? = .harp
      var body: some View {
        InstrumentIconPicker(suggested: .cello, choice: $choice)
      }
    }
    return Demo()
  }
#endif
