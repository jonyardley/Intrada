import SharedTypes
import SwiftUI

struct PracticeScreen: View {
  @Environment(Store.self) private var store
  @Environment(\.calendar) private var calendar
  @Environment(\.locale) private var locale

  // Injected so the weeks + auto-selection are deterministic in snapshots;
  // production uses "now".
  private let referenceDate: Date
  @State private var selectedDay: Date?
  @State private var weekIndexOverride: Int?
  // Shell state by decision 9 of specs/up-next-card.md: dismissal lasts the app
  // run, has no domain consequence and is deliberately not persisted.
  @State private var suggestionDismissed = false
  @State private var openSessionId: String?

  init(referenceDate: Date = Date()) {
    self.referenceDate = referenceDate
  }

  #if DEBUG
    /// Snapshot seed: open on a specific day (e.g. a quiet one) without a tap.
    init(referenceDate: Date, selectedDay: Date) {
      self.referenceDate = referenceDate
      _selectedDay = State(initialValue: selectedDay)
    }

    /// Snapshot seed: land as if "Build my own instead" had already been
    /// tapped (#1618), without driving the tap.
    init(referenceDate: Date, suggestionDismissed: Bool) {
      self.referenceDate = referenceDate
      _suggestionDismissed = State(initialValue: suggestionDismissed)
    }
  #endif

  private var sessions: [PracticeSessionView] { store.viewModel?.sessions ?? [] }
  private var weeks: [[Date]] {
    PracticeWeek.weeks(forSessions: sessions, referenceDate: referenceDate, calendar: calendar)
  }
  private var practiceDays: Swift.Set<Date> {
    PracticeWeek.practiceDays(from: sessions, calendar: calendar)
  }
  // Defaults to the last (current) week; a swipe overrides it.
  private var effectiveWeekIndex: Int {
    min(weekIndexOverride ?? (weeks.count - 1), weeks.count - 1)
  }
  private var selectedWeek: [Date] { weeks[effectiveWeekIndex] }
  private var effectiveSelection: Date {
    selectedDay
      ?? PracticeWeek.selectedDay(
        forWeek: selectedWeek, today: referenceDate, practiceDays: practiceDays, calendar: calendar)
  }
  private var daySessions: [PracticeSessionView] {
    PracticeWeek.sessions(on: effectiveSelection, from: sessions, calendar: calendar)
  }

  var body: some View {
    ScreenScaffold(title: "Practice", subtitle: subtitle) {
      ScrollView {
        VStack(spacing: IntradaSpacing.section) {
          if let recoverable = store.recoverableSession {
            RecoveryPromptCard(
              session: recoverable,
              referenceDate: referenceDate,
              onResume: { store.resumeRecoverableSession() },
              onDiscard: { store.discardSessionInProgress() }
            )
            .fadeUp(0)
          }
          heroSection
            .fadeUp(0)
          thisWeek
            .fadeUp(1)
          selectedDaySection
            .fadeUp(2)
        }
        .padding(.horizontal, IntradaSpacing.card)
        .padding(.top, IntradaSpacing.card)
        .padding(.bottom, IntradaSpacing.section)
      }
      .scrollEdgeShadow()
    }
    // Drop a now-out-of-range pinned week so a later data change can't jump the
    // view to a stale page; reads are already clamped, this resets the store.
    .onChange(of: weeks.count) { _, newCount in
      if let pinned = weekIndexOverride, pinned >= newCount { weekIndexOverride = nil }
    }
    // State-driven: `startBuilding` makes `buildingSetlist` non-nil → push; a
    // pop sends `cancelBuilding` → core returns to Idle. No local nav flag.
    .navigationDestination(isPresented: buildingBinding) {
      SessionBuilderScreen()
    }
    // Item-driven, not a NavigationLink: a link renders its label as a button,
    // and even with .buttonStyle(.plain) SwiftUI tints the whole screen a shade
    // lighter, which four Practice snapshots caught (#1371). The card must look
    // the same whether or not it happens to be tappable.
    .navigationDestination(item: $openSessionId) { id in
      if let found = sessions.first(where: { $0.id == id }) {
        PracticeSessionDetailScreen(session: found)
      }
    }
  }

  private var buildingBinding: Binding<Bool> {
    Binding(
      get: { store.viewModel?.buildingSetlist != nil },
      set: { presented in
        if !presented { store.send(.session(.cancelBuilding)) }
      })
  }

  // MARK: - (0) The suggestion, or one tap to the next

  private var lastPractised: LastPractisedView? { store.viewModel?.lastPractised }

  /// `nil` whenever nothing qualifies or the user has waved it away, which is
  /// what keeps the card a suggestion and never a gate (design-principles T15).
  private var suggestion: SuggestedSession? {
    suggestionDismissed ? nil : store.viewModel?.upNext
  }

  @ViewBuilder private var heroSection: some View {
    VStack(spacing: IntradaSpacing.cardCompact) {
      if let suggestion {
        UpNextHero(
          suggestion: suggestion,
          onStart: {
            store.send(
              .session(.startBuildingFromSuggestion(now: SessionClock.nowRFC3339())),
              onSuccess: .impact)
          },
          // "Build my own" is a decision, not a dismissal (#1617).
          onBuildOwn: {
            withAnimation(IntradaMotion.standard) { suggestionDismissed = true }
            store.send(.session(.startBuilding))
          }
        )
        .transition(.opacity)
      } else {
        hero
        if showsSuggestionRestore { suggestionRestoreButton }
      }

      if showsPriorities { prioritiesButton }
    }
  }

  // Text, never a filled CTA: two buttons a thumb apart that both start a
  // session is the ambiguity T15 rejected for the Up next card (T20).
  private var showsPriorities: Bool { Self.showsPriorities(store.viewModel) }

  /// Something is starred and nothing else is under way, so the tap cannot land
  /// on the core's "a practice is already in progress" refusal (#981).
  static func showsPriorities(_ viewModel: ViewModel?) -> Bool {
    guard let viewModel else { return false }
    return viewModel.hasPriorities && viewModel.buildingSetlist == nil
      && viewModel.activeSession == nil && viewModel.summary == nil
  }

  private var prioritiesButton: some View {
    Button {
      store.send(
        .session(.startBuildingWithPriorities(now: SessionClock.nowRFC3339())),
        onSuccess: .impact)
    } label: {
      HStack(spacing: IntradaSpacing.controlGap) {
        Image(systemName: "star.fill")
          .accessibilityHidden(true)
        Text("Practise your priorities")
      }
      .font(IntradaFont.subtitle)
      .foregroundStyle(IntradaColor.inkSecondary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, IntradaSpacing.controlGap)
    }
    .buttonStyle(PressRebound())
    .accessibilityHint("Builds a session from everything you have starred")
  }

  /// True once the suggestion has been waved away but the core still has one
  /// to offer: dismissal is not a one-way door (#1618).
  static func showsSuggestionRestore(_ viewModel: ViewModel?, dismissed: Bool) -> Bool {
    guard dismissed, let viewModel else { return false }
    return viewModel.upNext != nil && viewModel.buildingSetlist == nil
      && viewModel.activeSession == nil && viewModel.summary == nil
  }

  private var showsSuggestionRestore: Bool {
    Self.showsSuggestionRestore(store.viewModel, dismissed: suggestionDismissed)
  }

  private var suggestionRestoreButton: some View {
    Button {
      withAnimation(IntradaMotion.standard) { suggestionDismissed = false }
    } label: {
      HStack(spacing: IntradaSpacing.controlGap) {
        Image(systemName: "arrow.counterclockwise")
          .accessibilityHidden(true)
        Text("Show suggestion")
      }
      .font(IntradaFont.subtitle)
      .foregroundStyle(IntradaColor.inkSecondary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, IntradaSpacing.controlGap)
    }
    .buttonStyle(PressRebound())
    .accessibilityHint("Brings back the suggested session")
  }

  private var hero: some View {
    VStack(spacing: IntradaSpacing.cardCompact) {
      // One element carrying all three strings: the day sits below the button
      // visually, so read separately it would reach VoiceOver detached from
      // the piece it describes.
      VStack(spacing: IntradaSpacing.cardCompact) {
        Eyebrow(heroEyebrow, tint: IntradaColor.onAccent.opacity(0.7))

        if let lastPractised {
          Text(lastPractised.itemTitle)
            .font(IntradaFont.pageTitle(25))
            .foregroundStyle(IntradaColor.paperTop)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(heroLabel)

      Button {
        store.send(.session(.startBuilding))
      } label: {
        Image(systemName: "play.fill")
          .font(.system(size: 38))
          .foregroundStyle(IntradaColor.onMarker)
          .frame(width: 96, height: 96)
          .background(IntradaColor.marker)
          .clipShape(Circle())
          .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
      }
      .buttonStyle(PressRebound())
      .accessibilityLabel("Start practising")
      .padding(.vertical, IntradaSpacing.controlGap)

      if let lastPractised {
        Text(lastPractised.relativeDay)
          .font(IntradaFont.bodyMedium)
          .foregroundStyle(IntradaColor.onAccent.opacity(0.85))
          .multilineTextAlignment(.center)
          .accessibilityHidden(true)  // already spoken as part of heroLabel
      }
    }
    .frame(maxWidth: .infinity)
    .padding(IntradaSpacing.section)
    .background(LinearGradient.practiceHero)
    .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.hero))
    .heroShadow()
  }

  private var heroEyebrow: String {
    lastPractised == nil ? "First session" : "Last practised"
  }

  private var heroLabel: String {
    guard let lastPractised else { return heroEyebrow }
    return "\(heroEyebrow), \(lastPractised.itemTitle), \(lastPractised.relativeDay)"
  }

  // MARK: - (1) This week

  private var thisWeek: some View {
    let count = PracticeWeek.practisedCount(
      inWeek: selectedWeek, practiceDays: practiceDays, calendar: calendar)
    return VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      SectionHeader(
        title: "This week",
        trailing: "\(count) day\(count == 1 ? "" : "s") practised")
      weekStrips
    }
  }

  // Under UI tests the paging TabView's animation never lets the app idle, so
  // XCUITest stalls (#941) — show the current week statically instead.
  @ViewBuilder private var weekStrips: some View {
    Group {
      if UITestFlags.animationsDisabled {
        weekStripView(selectedWeek)
      } else {
        TabView(selection: weekBinding) {
          ForEach(Array(weeks.enumerated()), id: \.offset) { index, days in
            weekStripView(days).tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
      }
    }
    .frame(height: 64)
  }

  private func weekStripView(_ days: [Date]) -> some View {
    WeekStrip(
      days: days, today: referenceDate, practiceDays: practiceDays,
      selected: Binding(get: { effectiveSelection }, set: { selectedDay = $0 }),
      calendar: calendar
    )
  }

  // MARK: - (2) Selected day

  private var selectedDaySection: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      HStack(alignment: .firstTextBaseline) {
        Eyebrow(dayLabel)
        Spacer(minLength: IntradaSpacing.controlGap)
        Text(dayCountLabel)
          .font(IntradaFont.meta)
          .foregroundStyle(IntradaColor.inkSecondary)
      }
      dayContent
    }
  }

  private var dayCountLabel: String {
    if !daySessions.isEmpty {
      let count = daySessions.count
      return "\(count) session\(count == 1 ? "" : "s")"
    }
    return isFutureSelection ? "Yet to come" : "Rest day"
  }

  private var isFutureSelection: Bool {
    calendar.startOfDay(for: effectiveSelection) > calendar.startOfDay(for: referenceDate)
  }

  @ViewBuilder private var dayContent: some View {
    if daySessions.isEmpty {
      emptyDayCard
    } else {
      VStack(spacing: IntradaSpacing.cardCompact) {
        ForEach(daySessions, id: \.id) { session in
          SessionCard(session: session)
            .contentShape(Rectangle())
            .onTapGesture { openSessionId = session.id }
            // The trait alone only relabels it; the action is what VoiceOver and
            // Switch Control actually invoke, since this is a gesture not a Button.
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { openSessionId = session.id }
            .accessibilityHint("Opens the session")
        }
      }
    }
  }

  private var emptyDayCard: some View {
    VStack(spacing: IntradaSpacing.cardCompact) {
      Image(systemName: isFutureSelection ? "sunrise" : "moon")
        .font(.system(size: 28))
        .foregroundStyle(IntradaColor.inkSecondary)
      Text(isFutureSelection ? "Nothing logged yet" : "No practice logged")
        .font(IntradaFont.bodyMedium)
        .foregroundStyle(IntradaColor.inkSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(IntradaSpacing.card)
    .background(IntradaColor.cardFill)
    .clipShape(RoundedRectangle(cornerRadius: IntradaRadius.card))
    .overlay(
      RoundedRectangle(cornerRadius: IntradaRadius.card)
        .strokeBorder(
          IntradaColor.slotOutline,
          style: StrokeStyle(lineWidth: 1, dash: [5]))
    )
  }

  private var dayLabel: String {
    if calendar.isDateInToday(effectiveSelection) { return "Today" }
    if calendar.isDateInYesterday(effectiveSelection) { return "Yesterday" }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = locale  // env locale, not Locale.current (see SessionCard)
    formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
    return formatter.string(from: effectiveSelection)
  }

  // Swiping to another week clears the day selection so that week auto-selects
  // its own day (most recent practice, or its last day).
  private var weekBinding: Binding<Int> {
    Binding(
      get: { effectiveWeekIndex },
      set: { newIndex in
        weekIndexOverride = newIndex
        selectedDay = nil
      })
  }

  private var subtitle: String {
    lastPractised?.label ?? "No sessions yet"
  }
}

#if DEBUG
  #Preview("Populated") {
    PracticeScreen(referenceDate: PracticeSessionView.previewReferenceDate)
      .environment(Store.previewPractice)
  }

  #Preview("Up next") {
    PracticeScreen(referenceDate: PracticeSessionView.previewReferenceDate)
      .environment(Store.previewPracticeSuggestion)
  }

  #Preview("Empty") {
    PracticeScreen()
      .environment(Store.preview)
  }
#endif
