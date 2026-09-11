import SwiftUI

extension View {
  /// The feathered highlighter under a page title (#1676).
  func markerSwipe() -> some View {
    modifier(MarkerSwipe())
  }
}

private struct MarkerSwipe: ViewModifier {
  @Environment(\.marker) private var marker

  func body(content: Content) -> some View {
    content.background(
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0.50),
          .init(color: marker.opacity(0.6), location: 0.53),
          .init(color: marker, location: 0.58),
          .init(color: marker, location: 0.89),
          .init(color: marker.opacity(0.6), location: 0.93),
          .init(color: .clear, location: 0.96),
        ],
        startPoint: .top, endPoint: .bottom
      ),
      in: RoundedRectangle(cornerRadius: IntradaRadius.card)
    )
  }
}
