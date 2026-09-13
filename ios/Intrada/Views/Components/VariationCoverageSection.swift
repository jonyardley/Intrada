import SharedTypes
import SwiftUI

/// One card per exercise, saying how many of its variations are solid (#1762).
struct VariationCoverageSection: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  let rows: [VariationCoverageView]

  var body: some View {
    let solid = rows.reduce(0) { $0 + Int($1.solid) }
    let total = rows.reduce(0) { $0 + Int($1.total) }
    VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      SectionHeader(title: "Variations", trailing: "\(solid) of \(total) solid")
      VStack(spacing: IntradaSpacing.cardCompact) {
        ForEach(rows, id: \.itemId) { row in
          VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
            if dynamicTypeSize.isAccessibilitySize {
              title(row)
              count(row)
            } else {
              HStack(alignment: .firstTextBaseline, spacing: IntradaSpacing.cardCompact) {
                title(row)
                  .frame(maxWidth: .infinity, alignment: .leading)
                count(row)
              }
            }
            SegmentedProgress(
              count: Int(row.total), filled: Int(row.solid),
              label: "\(row.solid) of \(row.total) solid")
          }
          .padding(IntradaSpacing.cardCompact)
          .cardSurface(cornerRadius: IntradaRadius.card)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("\(row.title), \(row.solid) of \(row.total) variations solid")
        }
      }
    }
  }

  private func title(_ row: VariationCoverageView) -> some View {
    Text(row.title)
      .font(IntradaFont.bodyMedium)
      .foregroundStyle(IntradaColor.ink)
  }

  private func count(_ row: VariationCoverageView) -> some View {
    Text("\(row.solid) of \(row.total) solid")
      .font(IntradaFont.meta)
      .foregroundStyle(IntradaColor.inkSecondary)
  }
}
