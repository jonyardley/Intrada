import SharedTypes
import SwiftUI

/// Minimal variation-creation sheet: ordered labels in, `setVariants` out.
/// Only ever opened from an exercise with none yet, so there are no existing
/// variations to rename/reorder/archive here: that is the detail screen's
/// edit mode, once some exist.
struct AddVariationsSheet: View {
  let itemId: String

  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var labels: [String] = ["", ""]

  var body: some View {
    BottomSheet(
      title: "Variations", confirmationLabel: "Save",
      confirmationDisabled: trimmedLabels.isEmpty,
      onDone: save
    ) {
      ScrollView {
        VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
          Eyebrow("Variations, in order")
          VStack(spacing: IntradaSpacing.controlGap) {
            ForEach(Array(labels.indices), id: \.self) { index in
              variationRow(index)
            }
          }
          AddRowButton(title: "Add a variation", style: .plain) {
            labels.append("")
          }
        }
        .padding(IntradaSpacing.card)
      }
    }
  }

  private func variationRow(_ index: Int) -> some View {
    HStack(spacing: IntradaSpacing.controlGap) {
      TextField("e.g. C", text: Binding(get: { labels[index] }, set: { labels[index] = $0 }))
        .font(IntradaFont.field)
        .foregroundStyle(IntradaColor.ink)
        .padding(IntradaSpacing.cardCompact)
        .cardSurface(cornerRadius: IntradaRadius.control)
      if labels.count > 1 {
        Button {
          labels.remove(at: index)
        } label: {
          Image(systemName: "minus.circle")
            .font(IntradaFont.bodyMedium)
            .foregroundStyle(IntradaColor.danger)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove variation \(index + 1)")
      }
    }
  }

  private var trimmedLabels: [String] {
    Self.trimmedLabels(labels)
  }

  /// Trims and drops blank rows, pulled out as a static func so it is directly
  /// testable without driving the sheet.
  static func trimmedLabels(_ labels: [String]) -> [String] {
    labels.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
  }

  private func save() {
    let trimmed = trimmedLabels
    guard !trimmed.isEmpty else { return }
    store.send(.item(.setVariants(id: itemId, labels: trimmed)))
  }
}

#if DEBUG
  #Preview("Add variations") {
    Color.black.opacity(0.2).ignoresSafeArea()
      .sheet(isPresented: .constant(true)) {
        AddVariationsSheet(itemId: "preview-item").environment(Store.preview)
      }
  }
#endif
