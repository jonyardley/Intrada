import Foundation
import SharedTypes

extension PracticeSessionView {
  /// Parsed start instant. Routed through `SessionClock` so chrono's
  /// micro/nanosecond fractions parse (the bare `.withFractionalSeconds`
  /// formatter only handles milliseconds).
  var startedDate: Date? { SessionClock.parseRFC3339(startedAt) }

  /// Locale and calendar come from the caller's SwiftUI environment, never
  /// `Locale.current`: the template reorders by region and the day bucket
  /// shifts by timezone, which snapshot hosts pin and production must not.
  func dateDisplay(locale: Locale, calendar: Calendar) -> String {
    guard let date = startedDate else { return "" }
    if calendar.isDateInToday(date) { return "Today" }
    if calendar.isDateInYesterday(date) { return "Yesterday" }
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
    return formatter.string(from: date)
  }

  /// "3 pieces", "2 exercises", or "5 items" when the session spans both.
  var itemCountDisplay: String {
    let count = entries.count
    let noun: String
    if entries.allSatisfy({ $0.itemType == .piece }) {
      noun = count == 1 ? "piece" : "pieces"
    } else if entries.allSatisfy({ $0.itemType == .exercise }) {
      noun = count == 1 ? "exercise" : "exercises"
    } else {
      noun = count == 1 ? "item" : "items"
    }
    return "\(count) \(noun)"
  }
}

/// Pure date math for the Practice week strip. Shell-side per the dumb-pipe
/// call (#904 tracks lifting this into the core once Track needs the same
/// derived data). Every function takes an explicit `calendar` so callers pin
/// the timezone/locale for deterministic tests.
enum PracticeWeek {
  /// Monday-anchored week (7 start-of-day dates, ascending) containing `date`.
  static func days(containing date: Date, calendar: Calendar) -> [Date] {
    var calendar = calendar
    calendar.firstWeekday = 2  // Monday
    let start = calendar.startOfDay(for: date)
    guard let week = calendar.dateInterval(of: .weekOfYear, for: start) else { return [start] }
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
  }

  static func practiceDays(from sessions: [PracticeSessionView], calendar: Calendar)
    -> Swift.Set<Date>
  {
    // Swift.Set: the domain `Set` entity (SharedTypes) shadows Swift.Set here.
    Swift.Set(sessions.compactMap { $0.startedDate.map(calendar.startOfDay(for:)) })
  }

  /// How many of `week`'s days carry practice. The header count next to the
  /// strip, scoped to the visible week rather than the all-time set (#1357).
  static func practisedCount(inWeek week: [Date], practiceDays: Swift.Set<Date>, calendar: Calendar)
    -> Int
  {
    week.filter { practiceDays.contains(calendar.startOfDay(for: $0)) }.count
  }

  /// Sorted newest-first.
  static func sessions(on day: Date, from sessions: [PracticeSessionView], calendar: Calendar)
    -> [PracticeSessionView]
  {
    sessions
      .filter { $0.startedDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false }
      .sorted { ($0.startedDate ?? .distantPast) > ($1.startedDate ?? .distantPast) }
  }

  /// The weeks to page through: from the earliest session's week up to the
  /// week containing `referenceDate`, inclusive and ascending. Just the current
  /// week when there are no (earlier) sessions.
  static func weeks(
    forSessions sessions: [PracticeSessionView], referenceDate: Date, calendar: Calendar
  ) -> [[Date]] {
    let currentWeek = days(containing: referenceDate, calendar: calendar)
    let currentStart = currentWeek.first ?? calendar.startOfDay(for: referenceDate)
    guard
      let earliest = sessions.compactMap(\.startedDate).min(),
      let earliestStart = days(containing: earliest, calendar: calendar).first,
      earliestStart < currentStart
    else { return [currentWeek] }

    var result: [[Date]] = []
    var cursor = earliestStart
    while cursor <= currentStart {
      let week = days(containing: cursor, calendar: calendar)
      result.append(week)
      guard
        let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week.first ?? cursor),
        let nextStart = days(containing: next, calendar: calendar).first,
        nextStart > cursor
      else { break }
      cursor = nextStart
    }
    return result
  }

  /// Which day to select for a given week. The current week selects today when
  /// it has practice, otherwise the most recent earlier practice day, otherwise
  /// today; a past week picks its most recent practice day, otherwise its last.
  static func selectedDay(
    forWeek week: [Date], today: Date, practiceDays: Swift.Set<Date>, calendar: Calendar
  ) -> Date {
    let todayStart = calendar.startOfDay(for: today)
    if week.contains(where: { calendar.isDate($0, inSameDayAs: todayStart) }) {
      if practiceDays.contains(todayStart) { return todayStart }
      return week.filter { $0 <= todayStart && practiceDays.contains($0) }.max() ?? todayStart
    }
    return week.filter { practiceDays.contains($0) }.max() ?? (week.last ?? todayStart)
  }
}
