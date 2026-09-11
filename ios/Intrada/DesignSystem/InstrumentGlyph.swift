import SharedTypes
import SwiftUI

/// The instrument icon set (#1693), one template asset per icon the core can
/// suggest. Names and labels follow the profile mock (#1690).
extension InstrumentIcon {
  var assetName: String {
    switch self {
    case .piano: "instrument-piano"
    case .acousticGuitar: "instrument-acoustic-guitar"
    case .electricGuitar: "instrument-electric-guitar"
    case .violin: "instrument-violin"
    case .cello: "instrument-cello"
    case .voice: "instrument-voice"
    case .flute: "instrument-flute"
    case .clarinet: "instrument-clarinet"
    case .saxophone: "instrument-saxophone"
    case .trumpet: "instrument-trumpet"
    case .drums: "instrument-drums"
    case .harp: "instrument-harp"
    case .other: "instrument-other"
    }
  }

  /// What a picker tile says.
  var tileLabel: String {
    switch self {
    case .piano: "Piano"
    case .acousticGuitar: "Guitar"
    case .electricGuitar: "Electric guitar"
    case .violin: "Violin"
    case .cello: "Cello"
    case .voice: "Voice"
    case .flute: "Flute"
    case .clarinet: "Clarinet"
    case .saxophone: "Saxophone"
    case .trumpet: "Trumpet"
    case .drums: "Drums"
    case .harp: "Harp"
    case .other: "Other"
    }
  }

  /// What VoiceOver reads.
  var accessibilityLabel: String {
    switch self {
    case .piano: "Piano and keys"
    case .acousticGuitar: "Acoustic guitar"
    case .electricGuitar: "Electric guitar and bass"
    case .violin: "Violin and viola"
    case .cello: "Cello and double bass"
    case .voice: "Voice"
    case .flute: "Flute"
    case .clarinet: "Clarinet and oboe"
    case .saxophone: "Saxophone"
    case .trumpet: "Trumpet and brass"
    case .drums: "Drums and percussion"
    case .harp: "Harp"
    case .other: "Plain note"
    }
  }

  /// Computed: the generated enum is not `Sendable`, so a stored static trips
  /// strict concurrency.
  static var all: [InstrumentIcon] {
    [
      .piano, .acousticGuitar, .electricGuitar, .violin, .cello, .voice, .flute, .clarinet,
      .saxophone, .trumpet, .drums, .harp, .other,
    ]
  }
}

/// One instrument icon drawn in ink at a `IntradaGlyph` size. The asset is a
/// template, so the tint is whatever `foregroundStyle` the caller sets.
struct InstrumentGlyph: View {
  let icon: InstrumentIcon
  var size: CGFloat = IntradaGlyph.tile

  var body: some View {
    Image(icon.assetName)
      .renderingMode(.template)
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .foregroundStyle(IntradaColor.ink)
      .accessibilityLabel(icon.accessibilityLabel)
  }
}

#if DEBUG
  #Preview {
    VStack(spacing: IntradaSpacing.card) {
      ForEach(InstrumentIcon.all, id: \.self) { icon in
        HStack(spacing: IntradaSpacing.card) {
          InstrumentGlyph(icon: icon, size: IntradaGlyph.bar)
          InstrumentGlyph(icon: icon)
          Text(icon.tileLabel)
        }
      }
    }
    .padding()
  }
#endif
