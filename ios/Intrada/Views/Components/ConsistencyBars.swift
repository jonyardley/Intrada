import SwiftUI

/// One week's bucket for `ConsistencyBars`.
struct ConsistencyWeek: Identifiable {
  let id = UUID()
  let label: String
  let minutes: Int
  var isCurrent: Bool = false
}

/// Weekly practice-minutes bars — comeback, not streak (no counter). The current
/// week is accented; bars grow from the baseline (`barGrow`, staggered) on appear,
/// settling to final height instantly under Reduce Motion.
struct ConsistencyBars: View {
  let weeks: [ConsistencyWeek]
  /// The tallest the busiest week's bar may draw, in points.
  private let maxBarHeight: CGFloat = 58

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.intradaMotionDisabled) private var motionDisabled
  @State private var grown = false

  private var peakMinutes: Int { max(1, weeks.map(\.minutes).max() ?? 1) }

  var body: some View {
    HStack(alignment: .bottom, spacing: 9) {
      ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
        VStack(spacing: 6) {
          Spacer(minLength: 0)
          RoundedRectangle(cornerRadius: 5)
            .fill(
              week.isCurrent
                ? AnyShapeStyle(LinearGradient.inkBar)
                : AnyShapeStyle(IntradaColor.consistencyTrack)
            )
            .frame(maxWidth: .infinity)
            .frame(height: barHeight(for: week))
            .shadow(
              color: week.isCurrent ? IntradaColor.accent.opacity(0.4) : .clear,
              radius: 6, x: 0, y: 4
            )
            .scaleEffect(y: scale, anchor: .bottom)
            .animation(animation(index: index), value: grown)
          Text(week.label)
            .font(IntradaFont.micro)
            .foregroundStyle(week.isCurrent ? IntradaColor.accent : IntradaColor.inkFaint)
            .fontWeight(week.isCurrent ? .semibold : .regular)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          "\(week.label): \(week.minutes) minutes\(week.isCurrent ? ", this week" : "")")
      }
    }
    .frame(height: maxBarHeight + 18, alignment: .bottom)
    .onAppear { grown = true }
  }

  private func barHeight(for week: ConsistencyWeek) -> CGFloat {
    max(6, CGFloat(week.minutes) / CGFloat(peakMinutes) * maxBarHeight)
  }

  private var animates: Bool {
    !reduceMotion && !motionDisabled && !UITestFlags.animationsDisabled
  }
  private var scale: CGFloat { (grown || !animates) ? 1 : 0 }

  private func animation(index: Int) -> Animation? {
    guard animates else { return nil }
    return IntradaMotion.barGrow.delay(Double(index) * IntradaMotion.barGrowStagger)
  }
}

#if DEBUG
  #Preview {
    ZStack {
      PaperBackground()
      ConsistencyBars(weeks: [
        ConsistencyWeek(label: "W1", minutes: 40),
        ConsistencyWeek(label: "W2", minutes: 75),
        ConsistencyWeek(label: "W3", minutes: 55),
        ConsistencyWeek(label: "W4", minutes: 95),
        ConsistencyWeek(label: "Now", minutes: 82, isCurrent: true),
      ])
      .padding(IntradaSpacing.card)
    }
  }
#endif
