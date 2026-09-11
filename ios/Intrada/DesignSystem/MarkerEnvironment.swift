import SwiftUI

private struct MarkerKey: EnvironmentKey {
  static let defaultValue: Color = IntradaColor.marker
}

extension EnvironmentValues {
  /// The highlighter the musician chose (#1677), set once at the root from the
  /// core's profile view so every marker surface follows the swatch.
  var marker: Color {
    get { self[MarkerKey.self] }
    set { self[MarkerKey.self] = newValue }
  }
}
