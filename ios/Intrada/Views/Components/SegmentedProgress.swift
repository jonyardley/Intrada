import SharedTypes
import SwiftUI

/// Discrete position indicator: N filled segments of M. Stepped (not a
/// continuous fill) so it reads as "which one", distinct from the timer's
/// continuous target bar. A setlist passes its item types so the strip can
/// carry a per-type tint; a plain count fills in one colour.
struct SegmentedProgress: View {
  private let fills: [Color]
  private let filled: Int
  private let spokenLabel: String
  private let height: CGFloat

  init(types: [ItemKind], filled: Int, height: CGFloat = 4) {
    fills = types.map(\.accent)
    self.filled = filled
    spokenLabel = "Item \(filled) of \(types.count)"
    self.height = height
  }

  /// A plain count of equal segments: how many of an exercise's variations
  /// are solid, say (#1739).
  init(
    count: Int, filled: Int, fill: Color = IntradaColor.accent, label: String,
    height: CGFloat = 6
  ) {
    fills = Array(repeating: fill, count: max(count, 0))
    self.filled = filled
    spokenLabel = label
    self.height = height
  }

  var body: some View {
    HStack(spacing: 5) {
      ForEach(Array(fills.enumerated()), id: \.offset) { index, fill in
        Capsule()
          .fill(index < filled ? fill : IntradaColor.divider)
          .frame(height: height)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(spokenLabel)
  }
}

#if DEBUG
  #Preview {
    ZStack {
      PaperBackground()
      VStack(spacing: IntradaSpacing.card) {
        SegmentedProgress(types: [.piece, .exercise, .exercise, .piece, .piece], filled: 2)
        SegmentedProgress(count: 12, filled: 7, label: "7 of 12 solid")
      }
      .padding(IntradaSpacing.card)
    }
  }
#endif
