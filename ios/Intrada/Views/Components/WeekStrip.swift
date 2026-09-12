import SharedTypes
import SwiftUI

/// The week picker — a Mon–Sun row that *selects a day*; the screen renders that
/// day's sessions below. A day is always selected (the screen auto-selects on
/// open). Today is marked with a ring, the selected day with a fill, practised
/// days carry a dot, and not-yet days dim.
struct WeekStrip: View {
  let days: [Date]
  let today: Date
  let practiceDays: Swift.Set<Date>
  @Binding var selected: Date
  let calendar: Calendar

  var body: some View {
    HStack(spacing: 4) {
      ForEach(days, id: \.self) { day in
        WeekDayCell(
          day: day,
          isToday: calendar.isDate(day, inSameDayAs: today),
          isSelected: calendar.isDate(day, inSameDayAs: selected),
          isFuture: calendar.startOfDay(for: day) > calendar.startOfDay(for: today),
          hasPractice: practiceDays.contains(calendar.startOfDay(for: day)),
          calendar: calendar
        ) { selected = day }
      }
    }
    .background(
      GeometryReader { geo in
        Color.clear.preference(key: WeekStripHeightKey.self, value: geo.size.height)
      }
    )
  }
}

/// Reports a cell's natural height so the strip can size itself (#1730).
struct WeekStripHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

private struct WeekDayCell: View {
  let day: Date
  let isToday: Bool
  let isSelected: Bool
  let isFuture: Bool
  let hasPractice: Bool
  let calendar: Calendar
  let onTap: () -> Void
  @Environment(\.locale) private var locale
  // Scales with Dynamic Type, capped so seven days still fit the screen (#1730).
  @ScaledMetric(relativeTo: .caption) private var dayCircleDiameter: CGFloat = 32
  private var cappedDayCircleDiameter: CGFloat { min(dayCircleDiameter, 36) }

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 5) {
        Text(weekdayInitial)
          .font(IntradaFont.micro)
          .fontWeight(isSelected || isToday ? .semibold : .regular)
          .foregroundStyle(isSelected || isToday ? IntradaColor.accent : IntradaColor.inkFaint)
        Text(dayNumber)
          .font(IntradaFont.metaMedium)
          .foregroundStyle(dayNumberColor)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .frame(width: cappedDayCircleDiameter, height: cappedDayCircleDiameter)
          .background(isSelected ? IntradaColor.accent : .clear, in: Circle())
          .overlay(
            Circle().strokeBorder(
              IntradaColor.accent, lineWidth: isToday && !isSelected ? 1.5 : 0)
          )
        Circle()
          .fill(hasPractice ? IntradaColor.accent : .clear)
          .frame(width: 5, height: 5)
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  private var dayNumberColor: Color {
    if isSelected { return IntradaColor.onAccent }
    return isFuture ? IntradaColor.futureDay : IntradaColor.ink
  }

  private var dayNumber: String {
    String(calendar.component(.day, from: day))
  }

  private var weekdayInitial: String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = calendar
    formatter.setLocalizedDateFormatFromTemplate("EEEEE")
    return formatter.string(from: day)
  }

  private var accessibilityLabel: String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = calendar
    formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
    var label = formatter.string(from: day)
    if isToday { label = "Today, \(label)" }
    label += hasPractice ? ", practised" : ", no practice"
    return label
  }
}

#if DEBUG
  #Preview {
    struct Harness: View {
      @State private var selected = Calendar.current.startOfDay(for: .now)
      var body: some View {
        let cal = Calendar.current
        let week = PracticeWeek.days(containing: .now, calendar: cal)
        return ZStack {
          PaperBackground()
          WeekStrip(
            days: week, today: .now,
            practiceDays: Swift.Set([week[1], week[3]]),
            selected: $selected, calendar: cal
          )
          .padding(IntradaSpacing.card)
        }
      }
    }
    return Harness()
  }
#endif
