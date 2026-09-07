import SwiftUI

/// A chord chart staged on the create form, shown as the text that was typed:
/// monospaced, clamped, verbatim.
///
/// Deliberately not a bar count or a grid. The chart is parsed when Add is
/// pressed, so anything here that looked parsed would claim a verdict the form
/// has not asked for yet, and would be wrong exactly when it mattered.
struct StagedChartCard: View {
  @Environment(\.dynamicTypeSize) private var typeSize

  let text: String
  /// Non-nil when a photographed page filled this, `true` for a weak read.
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

  /// Two lines at accessibility sizes: the block is reassurance that the paste
  /// landed, and a section label plus one bar line does that.
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
