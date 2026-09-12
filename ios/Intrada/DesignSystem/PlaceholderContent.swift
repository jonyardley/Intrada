import SwiftUI

/// A centred "nothing here yet" body: tinted glyph + one line of muted copy.
struct PlaceholderContent: View {
  let systemImage: String
  let message: String
  var glyphTint: Color = IntradaColor.accent.opacity(0.55)
  @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 40

  var body: some View {
    VStack(spacing: IntradaSpacing.cardCompact) {
      Image(systemName: systemImage)
        .font(.system(size: glyphSize, weight: .regular))
        .foregroundStyle(glyphTint)
      Text(message)
        .font(IntradaFont.body)
        .foregroundStyle(IntradaColor.inkFaint)
        .multilineTextAlignment(.center)
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(message)
  }
}

#if DEBUG
  #Preview {
    ZStack {
      PaperBackground()
      PlaceholderContent(
        systemImage: "music.note",
        message: "Start a focused practice session here.")
    }
  }
#endif
