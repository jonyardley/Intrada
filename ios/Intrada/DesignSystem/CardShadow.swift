import SwiftUI

extension View {
  /// The app's single soft elevation recipe (previously inline in KeyPicker).
  /// Lifts a card or layer off the paper so stacked surfaces read as separate.
  /// `above: true` casts the shadow upward — for a bottom panel the content
  /// slides *under*, e.g. the builder's queue tray.
  func cardShadow(above: Bool = false) -> some View {
    shadow(color: IntradaColor.shadow, radius: 1, x: 0, y: above ? -1 : 1)
  }

  /// The deeper elevation the Practice hero sits on — the app's largest card,
  /// and the only one that needs to float this far off the paper.
  func heroShadow() -> some View {
    shadow(color: .black.opacity(0.18), radius: 20, y: 10)
  }
}
