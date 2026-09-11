import SharedTypes
import SwiftUI

/// The type-language pairing — colour + glyph + label per `ItemKind` — defined
/// once here so every type-coded surface (card bars, badges, chips) stays in
/// sync. Piece = blue-grey + note; Exercise = sand + dumbbell.
extension ItemKind {
  /// Ink for both kinds: a pastel border on white misses 3:1 (WCAG 1.4.11).
  var accent: Color { IntradaColor.accent }

  var onAccent: Color { IntradaColor.onAccent }

  var onHeroAccent: Color {
    switch self {
    case .piece: IntradaColor.onHeroPiece
    case .exercise: IntradaColor.onHeroExercise
    }
  }

  var bar: LinearGradient {
    switch self {
    case .piece: .pieceBar
    case .exercise: .exerciseBar
    }
  }

  var iconName: String {
    switch self {
    case .piece: "music.note"
    case .exercise: "dumbbell.fill"
    }
  }

  var label: String {
    switch self {
    case .piece: "Piece"
    case .exercise: "Exercise"
    }
  }

  var caption: String {
    switch self {
    case .piece: "Repertoire to learn and keep up"
    case .exercise: "Drills and studies to build technique"
    }
  }
}
