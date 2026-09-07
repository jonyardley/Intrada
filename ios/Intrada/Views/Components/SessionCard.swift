import SharedTypes
import SwiftUI

/// A past-practice row on the Practice home. Sessions span item types, so
/// there's no type-coded left bar (unlike the single-type library rows).
struct SessionCard: View {
  let session: PracticeSessionView
  @Environment(\.locale) private var locale
  @Environment(\.calendar) private var calendar

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(dateDisplay)
        .font(IntradaFont.cardTitle())
        .foregroundStyle(IntradaColor.ink)
      Text(metaLine)
        .font(IntradaFont.meta)
        .foregroundStyle(IntradaColor.inkSecondary)
      if session.completionStatus == .endedEarly {
        Text("Ended early")
          .font(IntradaFont.micro)
          .foregroundStyle(IntradaColor.inkFaint)
          .padding(.top, 2)
      }
    }
    .padding(.vertical, IntradaSpacing.row)
    .padding(.horizontal, IntradaSpacing.card)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(IntradaColor.cardFill)
    .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.card))
    .overlay(
      RoundedRectangle(cornerRadius: IntradaRadius.card)
        .stroke(IntradaColor.hairline, lineWidth: 1)
    )
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  private var metaLine: String {
    "\(session.totalDurationSummary) · \(session.itemCountDisplay)"
  }

  private var dateDisplay: String {
    session.dateDisplay(locale: locale, calendar: calendar)
  }

  private var accessibilityLabel: String {
    var parts = [dateDisplay, session.totalDurationSummary, session.itemCountDisplay]
    if session.completionStatus == .endedEarly { parts.append("ended early") }
    return parts.joined(separator: ", ")
  }
}

#if DEBUG
  #Preview {
    ZStack {
      PaperBackground()
      VStack(spacing: IntradaSpacing.row) {
        SessionCard(session: .previewCompleted)
        SessionCard(session: .previewEndedEarly)
      }
      .padding(IntradaSpacing.card)
    }
  }
#endif
