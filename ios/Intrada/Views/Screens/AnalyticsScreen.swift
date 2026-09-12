import SharedTypes
import SwiftUI

struct AnalyticsScreen: View {
  @Environment(Store.self) private var store
  @Environment(\.calendar) private var calendar

  private var analytics: AnalyticsView? { store.viewModel?.analytics }

  var body: some View {
    ScreenScaffold(title: "Progress", subtitle: subtitle) {
      content
    }
  }

  @ViewBuilder private var content: some View {
    if let analytics {
      ScrollView {
        VStack(alignment: .leading, spacing: IntradaSpacing.section) {
          if let mover = topMover(analytics) {
            MasteryDeltaToast(
              title: "Mastery up", subtitle: mover.itemTitle,
              was: Int(mover.previousScore ?? 0), now: Int(mover.currentScore)
            )
            .fadeUp(0)
          }
          heroCard(analytics)
            .fadeUp(1)
          if !variationCoverage.isEmpty {
            variationSection
              .fadeUp(2)
          }
          consistencySection(analytics)
            .fadeUp(3)
          recentMasterySection(analytics)
            .fadeUp(4)
        }
        .padding(.horizontal, IntradaSpacing.card)
        .padding(.top, IntradaSpacing.card)
        .padding(.bottom, IntradaSpacing.card)
      }
      .scrollEdgeShadow()
    } else {
      PlaceholderContent(
        systemImage: "chart.line.uptrend.xyaxis",
        message: "Progress will appear here once you start practising.")
    }
  }

  // ── Hero mastery ──

  private func heroCard(_ analytics: AnalyticsView) -> some View {
    MasteryHeroCard(
      mastery: overallMastery(analytics),
      monthDelta: avgDelta(analytics),
      itemsCovered: Int(analytics.weeklySummary.itemsCovered))
  }

  // ── Consistency ──

  private func consistencySection(_ analytics: AnalyticsView) -> some View {
    let weeks = weeklyBuckets(analytics)
    let maxMinutes = weeks.map(\.minutes).max() ?? 0
    return VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      SectionHeader(title: "This month", trailing: "best week · \(maxMinutes)m")
      ConsistencyBars(weeks: weeks)
    }
  }

  // ── Variations ──

  private var variationSection: some View {
    let rows = variationCoverage
    let solid = rows.reduce(0) { $0 + $1.solid }
    let total = rows.reduce(0) { $0 + $1.total }
    return VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      SectionHeader(title: "Variations", trailing: "\(solid) of \(total) solid")
      VStack(spacing: IntradaSpacing.cardCompact) {
        ForEach(rows) { row in
          VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
            HStack(alignment: .firstTextBaseline, spacing: IntradaSpacing.cardCompact) {
              Text(row.title)
                .font(IntradaFont.bodyMedium)
                .foregroundStyle(IntradaColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
              Text("\(row.solid) of \(row.total) solid")
                .font(IntradaFont.meta)
                .foregroundStyle(IntradaColor.inkSecondary)
            }
            SegmentedProgress(
              count: row.total, filled: row.solid,
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

  private var variationCoverage: [VariationCoverage] {
    VariationCoverage.rows(store.viewModel?.allItems ?? [])
  }

  // ── Recent mastery ──

  private func recentMasterySection(_ analytics: AnalyticsView) -> some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      Eyebrow("Recent mastery")
      VStack(spacing: IntradaSpacing.cardCompact) {
        ForEach(Array(analytics.scoreChanges.enumerated()), id: \.offset) { idx, change in
          MasteryDelta(
            title: change.itemTitle,
            subtitle: change.isNew ? "first time marked" : nil,
            was: change.previousScore.map(Int.init),
            now: Int(change.currentScore)
          )
          .fadeUp(5 + idx)
        }
      }
    }
  }

  // ── Derivations ──

  private var subtitle: String {
    guard let summary = analytics?.weeklySummary else { return "No sessions yet" }
    let h = summary.totalMinutes / 60
    let m = summary.totalMinutes % 60
    let duration = h == 0 ? "\(m)m" : "\(h)h \(m)m"
    return "\(summary.sessionCount) sessions · \(duration) this week"
  }

  private func overallMastery(_ analytics: AnalyticsView) -> Double {
    let trends = analytics.scoreTrends
    guard !trends.isEmpty else { return 0 }
    let total = trends.reduce(0.0) { $0 + Double($1.latestScore) }
    return total / Double(trends.count)
  }

  private func topMover(_ analytics: AnalyticsView) -> ScoreChange? {
    analytics.scoreChanges.filter { $0.delta > 0 }.max { $0.delta < $1.delta }
  }

  private func avgDelta(_ analytics: AnalyticsView) -> Double {
    let changes = analytics.scoreChanges
    guard !changes.isEmpty else { return 0 }
    let total = changes.reduce(0.0) { $0 + Double($1.delta) }
    return max(0, total / Double(changes.count))
  }

  // Roll the per-day totals into Monday-anchored weekly buckets, keeping the most
  // recent five and labelling the last "Now".
  private func weeklyBuckets(_ analytics: AnalyticsView) -> [ConsistencyWeek] {
    let parser = DateFormatter()
    parser.calendar = calendar
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = TimeZone(identifier: "UTC")
    parser.dateFormat = "yyyy-MM-dd"

    var weekCalendar = calendar
    weekCalendar.firstWeekday = 2
    if let utc = TimeZone(identifier: "UTC") { weekCalendar.timeZone = utc }

    var totals: [Date: Int] = [:]
    for daily in analytics.dailyTotals {
      guard let date = parser.date(from: daily.date),
        let interval = weekCalendar.dateInterval(of: .weekOfYear, for: date)
      else { continue }
      totals[interval.start, default: 0] += Int(daily.minutes)
    }

    let ordered = totals.sorted { $0.key < $1.key }.suffix(5)
    let lastIndex = ordered.count - 1
    return ordered.enumerated().map { idx, entry in
      let isCurrent = idx == lastIndex
      return ConsistencyWeek(
        label: isCurrent ? "Now" : "W\(idx + 1)",
        minutes: entry.value,
        isCurrent: isCurrent)
    }
  }
}

/// One exercise's variations and how many of them are solid.
struct VariationCoverage: Identifiable {
  let id: String
  let title: String
  let solid: Int
  let total: Int

  /// Coverage, not twenty rings: an exercise with twenty variations reads the
  /// same as one with three, and the per-variation detail stays on the
  /// exercise's own screen (#1739). Most recently practised first, capped so a
  /// large library does not take the screen over. One variation is not a set
  /// worth a bar, and an exercise never practised has nothing to report.
  static func rows(_ items: [LibraryItemView], limit: Int = 5) -> [VariationCoverage] {
    items
      .filter { $0.variants.count > 1 && ($0.practice?.sessionCount ?? 0) > 0 }
      .sorted { ($0.practice?.lastPracticedAt ?? "") > ($1.practice?.lastPracticedAt ?? "") }
      .prefix(limit)
      .map {
        VariationCoverage(
          id: $0.id, title: $0.title,
          solid: $0.variants.filter(\.isSolid).count, total: $0.variants.count)
      }
  }
}

#if DEBUG
  #Preview {
    AnalyticsScreen()
      .environment(Store.previewProgress)
  }

  #Preview("Empty") {
    AnalyticsScreen()
      .environment(Store.preview)
  }
#endif
