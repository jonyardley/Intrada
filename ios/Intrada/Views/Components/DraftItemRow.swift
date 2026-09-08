import SharedTypes
import SwiftUI

struct DraftItemRow: View {
  let title: String
  let meta: String?
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: IntradaSpacing.cardCompact) {
      // spacing: 3, a tight title/meta baseline gap below the token scale floor.
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(IntradaFont.cardTitle())
          .foregroundStyle(IntradaColor.ink)
          .fixedSize(horizontal: false, vertical: true)
        if let meta {
          Text(meta)
            .font(IntradaFont.meta)
            .foregroundStyle(IntradaColor.inkSecondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Button(action: onRemove) {
        Image(systemName: "minus.circle")
          .font(IntradaFont.bodyMedium)
          .foregroundStyle(IntradaColor.danger)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Remove \(title)")
    }
    .padding(.vertical, IntradaSpacing.controlGap)
    .padding(.leading, 20)
    .padding(.trailing, IntradaSpacing.controlGap)
    .background(IntradaColor.cardFill)
    .overlay(alignment: .leading) {
      ItemKind.exercise.bar.frame(width: 4)
    }
  }
}

#if DEBUG
  #Preview {
    VStack(spacing: 0) {
      DraftItemRow(title: "Shell voicings", meta: "C major", onRemove: {})
      HairlineDivider()
      DraftItemRow(title: "Guide tones, ii to V to I", meta: "C major · 80 bpm", onRemove: {})
    }
    .cardSurface()
    .padding(IntradaSpacing.card)
    .background(LinearGradient.paper)
  }
#endif
