import SharedTypes

/// The note value one click stands for. `♩ = 168` in 7/8 would be a lie the
/// ear catches, so the readout names the unit the metre counts in (T19). The
/// minim is spelt out: the bundled faces have no glyph for it and the fallback is tofu.
enum TempoUnit {
  static func glyph(_ unit: UInt8) -> String {
    switch unit {
    case 2: "minim"
    case 8: "♪"
    default: "♩"
    }
  }

  static func spokenName(_ unit: UInt8) -> String {
    switch unit {
    case 2: "minim"
    case 8: "quaver"
    default: "crotchet"
    }
  }

  static func readout(_ bpm: Int, unit: UInt8) -> String { "\(glyph(unit)) = \(bpm)" }

  static func spoken(_ bpm: Int, unit: UInt8) -> String {
    unit == 4 ? "\(bpm) beats per minute" : "\(bpm) \(spokenName(unit)) beats per minute"
  }

  static func metreLabel(_ metre: Metre) -> String { "\(metre.beats)/\(metre.unit)" }
}
