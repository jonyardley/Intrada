import SharedTypes
import SwiftUI

/// Tinted icon-chip badge for an item's type — used where a type-coded list bar
/// isn't present (e.g. the detail header). Piece = blue-grey, Exercise = sand.
struct TypeBadge: View {
  let kind: ItemKind

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: kind.iconName)
        .imageScale(.small)
      Text(kind.label)
    }
    .font(IntradaFont.badge)
    .foregroundStyle(foreground)
    .padding(.vertical, 5)
    .padding(.horizontal, 10)
    .background(
      background, in: RoundedRectangle(cornerRadius: IntradaRadius.badge, style: .continuous)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(kind.label)
  }

  private var foreground: Color {
    switch kind {
    case .piece: IntradaColor.pieceBadgeFg
    case .exercise: IntradaColor.exerciseBadgeFg
    }
  }

  private var background: Color {
    switch kind {
    case .piece: IntradaColor.pieceBadgeBg
    case .exercise: IntradaColor.exerciseBadgeBg
    }
  }
}

#if DEBUG
  #Preview {
    ZStack {
      PaperBackground()
      HStack(spacing: IntradaSpacing.cardCompact) {
        TypeBadge(kind: .piece)
        TypeBadge(kind: .exercise)
      }
    }
  }
#endif
