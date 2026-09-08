import SwiftUI

struct StagedChartCard: View {
  @Environment(\.dynamicTypeSize) private var typeSize

  let text: String
  let readWeakly: Bool?
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
          .stroke(IntradaColor.divider, lineWidth: 1)
      )
      .padding(.horizontal, IntradaSpacing.card)
      .padding(.bottom, readWeakly == nil ? IntradaSpacing.card : IntradaSpacing.controlGap)
      .accessibilityLabel("Chord chart, as typed")
      .accessibilityValue(text)
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
