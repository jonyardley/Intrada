import SwiftUI

/// One past practice session as a row in `RecentSessions`. Pure view data — the
/// caller maps `ItemPracticeSummary.scoreHistory` into these (newest first) and
/// formats `dateText` (the core stores an RFC3339 `session_date`).
struct RecentSession: Identifiable {
  let id: String
  let score: Int?
  let dateText: String
}

/// Past-practice history for a piece or exercise: a trend chip over rows of
/// `ScoreRing` + date. Shown on the detail screens to make progress visible.
/// Presentation only — the score history and its ordering come from the core.
struct RecentSessions: View {
  /// Newest first, matching the core's `score_history` ordering.
  let sessions: [RecentSession]

  /// Oldest → newest scored session, shown only when both ends carry a score
  /// and they actually moved.
  private var trend: (from: Int, to: Int)? {
    let scored = sessions.compactMap(\.score)
    guard scored.count >= 2, let newest = scored.first, let oldest = scored.last,
      oldest != newest
    else { return nil }
    return (oldest, newest)
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
        row(session)
        if index < sessions.count - 1 { HairlineDivider() }
      }
    }
    .padding(.horizontal, IntradaSpacing.card)
    .padding(.top, IntradaSpacing.cardCompact)
    .padding(.bottom, IntradaSpacing.controlGap)
    .cardSurface(cornerRadius: IntradaRadius.panel)
  }

  private var header: some View {
    HStack {
      Eyebrow("Recent sessions")
      Spacer()
      if let trend {
        let up = trend.to > trend.from
        HStack(spacing: 4) {
          // A drop is neutral taupe, never a red/green lie about the numbers.
          Image(systemName: up ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
            .accessibilityHidden(true)
          Text("\(trend.from) → \(trend.to)")
        }
        .font(IntradaFont.badge)
        .foregroundStyle(up ? IntradaColor.success : IntradaColor.inkSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "Trend, \(up ? "improved" : "declined") from \(trend.from) to \(trend.to)")
      }
    }
    .padding(.bottom, IntradaSpacing.controlGap)
  }

  private func row(_ session: RecentSession) -> some View {
    HStack(spacing: IntradaSpacing.cardCompact) {
      ScoreRing(score: session.score, size: 38)
      Text(session.dateText)
        .font(IntradaFont.metaMedium)
        .foregroundStyle(IntradaColor.inkSecondary)
      Spacer()
    }
    .padding(.vertical, IntradaSpacing.cardCompact)
    .accessibilityElement(children: .combine)
  }
}

#if DEBUG
  #Preview("Recent sessions") {
    ZStack {
      PaperBackground()
      RecentSessions(sessions: [
        RecentSession(id: "1", score: 7, dateText: "Tue · Jun 24"),
        RecentSession(id: "2", score: 6, dateText: "Sat · Jun 21"),
        RecentSession(id: "3", score: 5, dateText: "Wed · Jun 18"),
      ])
      .padding(IntradaSpacing.card)
    }
  }
#endif
