import SharedTypes
import SwiftUI

/// The player's variation picker (#1739 decision 6). Tapping a row switches the
/// open play; switching to the one already playing is the core's no-op, so a
/// stray tap cannot clear the repetition dots.
struct VariationPickerSheet: View {
  let itemTitle: String
  let variations: [VariantView]
  let currentVariationId: String?
  /// Returns false when the core refused the switch, which keeps the sheet up
  /// rather than closing over a chip that still names the old variation.
  let onPick: (String) -> Bool

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    BottomSheet(title: "Switch variation", detents: [.medium, .large]) {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(variations.enumerated()), id: \.element.id) { index, variation in
            if index > 0 {
              HairlineDivider().padding(.horizontal, IntradaSpacing.card)
            }
            row(variation)
          }
          Text("Switching starts a fresh count of repetitions.")
            .font(IntradaFont.meta)
            .foregroundStyle(IntradaColor.inkFaint)
            .padding(IntradaSpacing.card)
        }
        .padding(.top, IntradaSpacing.controlGap)
      }
    }
  }

  private func row(_ variation: VariantView) -> some View {
    let isCurrent = variation.id == currentVariationId
    return Button {
      if onPick(variation.id) { dismiss() }
    } label: {
      HStack(spacing: IntradaSpacing.cardCompact) {
        VStack(alignment: .leading, spacing: 2) {
          Text(variation.label)
            .font(IntradaFont.bodyMedium)
            .foregroundStyle(IntradaColor.ink)
            .multilineTextAlignment(.leading)
          Text(caption(variation, isCurrent: isCurrent))
            .font(IntradaFont.meta)
            .foregroundStyle(variation.isSolid ? IntradaColor.ink : IntradaColor.inkFaint)
            .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if isCurrent {
          Image(systemName: "checkmark")
            .font(IntradaFont.segment.weight(.semibold))
            .foregroundStyle(IntradaColor.accent)
        }
      }
      .padding(.horizontal, IntradaSpacing.card)
      .frame(minHeight: 56)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(variation.label), \(caption(variation, isCurrent: isCurrent))")
    .accessibilityHint(isCurrent ? "" : "Switches \(itemTitle) to this variation")
    .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
  }

  private func caption(_ variation: VariantView, isCurrent: Bool) -> String {
    if isCurrent { return "Playing now" }
    guard let score = variation.latestScore else { return "Not yet played" }
    return variation.isSolid ? "Solid · \(score) of 10" : "\(score) of 10"
  }
}

#if DEBUG
  #Preview("Variation picker") {
    Color.black.opacity(0.2).ignoresSafeArea()
      .sheet(isPresented: .constant(true)) {
        VariationPickerSheet(
          itemTitle: "Major Scales",
          variations: LibraryItemView.previewExerciseWithVariations.variants,
          currentVariationId: LibraryItemView.previewExerciseWithVariations.variants.first?.id,
          onPick: { _ in true })
      }
  }
#endif
