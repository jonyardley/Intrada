import SharedTypes
import SwiftUI

struct DraftItemRow: View {
  let title: String
  let meta: String?
  /// True while this is the row a refused save named, with `faultedField` the
  /// field inside it, where the core could say which (#1595).
  var faulted: Bool = false
  var faultedField: FormErrorField?
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: IntradaSpacing.cardCompact) {
      // spacing: 3, a tight title/meta baseline gap below the token scale floor.
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(IntradaFont.cardTitle())
          .foregroundStyle(IntradaColor.ink)
          .fixedSize(horizontal: false, vertical: true)
          // On the title, not the row: a container is not focusable, so a hint
          // on it is announced to nobody.
          .accessibilityHint(faulted ? FaultMark.spoken(row: faultedField) : "")
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
    .faultWash(faulted, over: IntradaColor.cardFill)
    .overlay(alignment: .leading) {
      if faulted {
        IntradaColor.danger.frame(width: 4)
      } else {
        ItemKind.exercise.bar.frame(width: 4)
      }
    }
  }
}

#if DEBUG
  #Preview {
    VStack(spacing: 0) {
      DraftItemRow(title: "Shell voicings", meta: "C major", onRemove: {})
      HairlineDivider()
      DraftItemRow(title: "Guide tones, ii to V to I", meta: "C major · 80 bpm", onRemove: {})
      HairlineDivider()
      DraftItemRow(
        title: "Untitled", meta: nil, faulted: true, faultedField: .title, onRemove: {})
    }
    .cardSurface()
    .padding(IntradaSpacing.card)
    .background(LinearGradient.paper)
  }
#endif
