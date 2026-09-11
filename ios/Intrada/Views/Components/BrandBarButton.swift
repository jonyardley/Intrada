import SwiftUI

/// The marker primary action bar (builder start, reflection save,
/// practise-this). Generic label content so icons can lead or trail.
struct BrandBarButton<Label: View>: View {
  private let action: () -> Void
  private let label: Label

  init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
    self.action = action
    self.label = label()
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: IntradaSpacing.controlGap) { label }
        .font(IntradaFont.button)
        .foregroundStyle(IntradaColor.onMarker)
        .frame(maxWidth: .infinity)
        .padding(.vertical, IntradaSpacing.row)
        .background(
          IntradaColor.marker, in: RoundedRectangle(cornerRadius: IntradaRadius.control)
        )
        .shadow(color: IntradaColor.buttonShadow, radius: 1, y: 1)
    }
    .buttonStyle(.plain)
  }
}
