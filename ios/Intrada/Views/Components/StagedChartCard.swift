import SharedTypes
import SwiftUI

struct StagedChartCard: View {
  @Environment(\.dynamicTypeSize) private var typeSize

  let text: String
  let readWeakly: Bool?
  /// True while the chart is what a refused save named, with `faultedBarNumber`
  /// the bar it stopped at where there was one to name (#1595).
  var faulted: Bool = false
  var faultedBarNumber: UInt64?
  let onEdit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      FormSectionRow(title: "Chord chart", accessory: .edit, action: onEdit)
      chartBlock
      if let readWeakly {
        FieldMark(weak: readWeakly)
          .padding(.horizontal, IntradaSpacing.card)
          .padding(.bottom, IntradaSpacing.cardCompact)
      }
    }
  }

  private var chartBlock: some View {
    Text(text)
      .font(IntradaFont.chart)
      .foregroundStyle(IntradaColor.ink)
      .lineLimit(lineLimit)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(IntradaSpacing.cardCompact)
      .background(
        IntradaColor.paperTop, in: RoundedRectangle(cornerRadius: IntradaRadius.badge)
      )
      .overlay(
        RoundedRectangle(cornerRadius: IntradaRadius.badge)
          .stroke(faulted ? IntradaColor.danger : IntradaColor.divider, lineWidth: 1)
      )
      .padding(.horizontal, IntradaSpacing.card)
      .padding(.bottom, readWeakly == nil ? IntradaSpacing.card : IntradaSpacing.controlGap)
      .accessibilityLabel("Chord chart, as typed")
      .accessibilityValue(text)
      .accessibilityHint(spokenFault)
  }

  private var spokenFault: String {
    guard faulted else { return "" }
    guard let bar = faultedBarNumber else { return FaultMark.hint }
    return "Bar \(bar): \(FaultMark.hint.prefix(1).lowercased())\(FaultMark.hint.dropFirst())"
  }

  private var lineLimit: Int {
    typeSize.isAccessibilitySize ? 2 : 3
  }
}

#if DEBUG
  #Preview("Typed") {
    StagedChartCard(
      text: "[A]\n| Dm7 | G7 | Cmaj7 | A7alt |\n| Dm7 | G7 | Cmaj7 | Cmaj7 |",
      readWeakly: nil, onEdit: {}
    )
    .cardSurface()
    .padding(IntradaSpacing.card)
    .background(LinearGradient.paper)
  }

  #Preview("Refused at a bar") {
    StagedChartCard(
      text: "| Dm7 | G7 | Hxyz | Cmaj7 |", readWeakly: nil, faulted: true,
      faultedBarNumber: 3, onEdit: {}
    )
    .cardSurface()
    .padding(IntradaSpacing.card)
    .background(LinearGradient.paper)
  }

  #Preview("Read from a page") {
    StagedChartCard(
      text: "| F7 | Bb7 | Eb6 | Cm7 |\n| F7 | Bb7 | Eb6 | Eb6 |",
      readWeakly: false, onEdit: {}
    )
    .cardSurface()
    .padding(IntradaSpacing.card)
    .background(LinearGradient.paper)
  }
#endif
