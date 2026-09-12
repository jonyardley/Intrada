import SharedTypes
import SwiftUI

/// The musician's instrument on their highlighter: the way into the profile
/// from the Practice header, the profile hero and the edit card (#1692).
struct ProfileBadge: View {
  let icon: InstrumentIcon
  var size: CGFloat = IntradaGlyph.tile

  @Environment(\.marker) private var marker

  var body: some View {
    InstrumentGlyph(icon: icon, size: size * Self.glyphShare)
      .foregroundStyle(IntradaColor.onMarker)
      .frame(width: size, height: size)
      .background(marker, in: Circle())
  }

  /// The glyph's share of the circle: 22pt of the 36pt header badge in the mock.
  private static let glyphShare: CGFloat = 0.62
}

extension HighlighterColour {
  /// The swatch row's order (the token sheet's), butter first.
  static var all: [HighlighterColour] {
    [.butter, .coral, .mint, .sky, .lavender, .sage, .peach, .powder]
  }

  var label: String {
    switch self {
    case .butter: "Butter"
    case .coral: "Coral"
    case .mint: "Mint"
    case .sky: "Sky"
    case .lavender: "Lavender"
    case .sage: "Sage"
    case .peach: "Peach"
    case .powder: "Powder"
    }
  }
}

#if DEBUG
  #Preview {
    HStack(spacing: IntradaSpacing.card) {
      ProfileBadge(icon: .cello, size: IntradaGlyph.bar)
      ProfileBadge(icon: .cello)
      ProfileBadge(icon: .other, size: IntradaGlyph.hero)
    }
    .padding()
    .background(PaperBackground())
  }
#endif
