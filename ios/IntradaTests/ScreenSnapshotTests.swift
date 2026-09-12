import IntradaCoreFFI
import SharedTypes
import SnapshotTesting
import SwiftUI
import XCTest

@testable import Intrada

private final class StubBridge: CoreBridge {
  private let core = CoreFfi()
  func update(_ event: Event) throws -> [Request] { [] }
  func resolve(_ id: UInt32, httpResult: HttpResult) throws -> [Request] { [] }
  func resolve(_ id: UInt32, persistenceOutput: PersistenceOutput) throws -> [Request] { [] }
  func resolve(_ id: UInt32, recognitionOutput: RecognitionOutput) throws -> [Request] { [] }
  func resolveEmpty(_ id: UInt32) throws -> [Request] { [] }
  func view() throws -> ViewModel {
    try ViewModel.bincodeDeserialize(input: [UInt8](core.view()))
  }
}

/// Force light mode at the controller level (SwiftUI reads colorScheme from
/// here, not the snapshot `traits:`) and pin `.iPhone13` + displayScale so the
/// host sim can't change the image; references recorded on iOS 26.5 to match CI.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
  override func setUp() {
    super.setUp()
    IntradaFonts.register()
  }

  private func host(_ view: some View, store: Store = Store(bridge: StubBridge()))
    -> UIViewController
  {
    // Pin locale + calendar so date-driven UI (SessionCard's date, the week
    // strip) is deterministic regardless of host region/timezone — CI runs
    // en-US/UTC, dev sims often en-GB/local, which reorder dates and shift
    // day boundaries.
    // Suppress intro motion: the refreshed screens' entrance/one-shot animations
    // (fadeUp, count-up, ring-draw, barGrow, confetti) collapse to their final
    // state, so the captured frame is the settled layout, never a mid-reveal.
    // (`accessibilityReduceMotion` is read-only, so we use our settable flag.)
    // The marker follows the store's profile here as it does under RootView.
    let vc = UIHostingController(
      rootView: view.environment(store)
        .environment(\.marker, IntradaColor.marker(store.viewModel?.profile.colour ?? .butter))
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.calendar, PreviewCalendar.utc)
        .environment(\.intradaMotionDisabled, true))
    vc.overrideUserInterfaceStyle = .light
    return vc
  }

  private var config: Snapshotting<UIViewController, UIImage> {
    .image(on: .iPhone13, perceptualPrecision: 0.98, traits: .init(displayScale: 2))
  }

  /// A frame tall enough to hold the whole add form: the chart and the staged
  /// rows sit below an iPhone 13's fold, so a device-sized frame captures the
  /// banner and nothing the marks do (#1595). Scale 1 keeps the reference
  /// smaller than a device-sized one despite the height.
  private var tallFormConfig: Snapshotting<UIViewController, UIImage> {
    .image(
      on: ViewImageConfig(
        safeArea: .zero, size: CGSize(width: 390, height: 1500), traits: .init(displayScale: 1)),
      perceptualPrecision: 0.98, traits: .init(displayScale: 1))
  }

  private var splitConfig: Snapshotting<UIViewController, UIImage> {
    .image(on: .iPadPro11(.landscape), perceptualPrecision: 0.98, traits: .init(displayScale: 1))
  }

  /// Largest accessibility text size — proves layouts reflow rather than clip/wrap.
  private var axConfig: Snapshotting<UIViewController, UIImage> {
    .image(
      on: .iPhone13, perceptualPrecision: 0.98,
      traits: UITraitCollection { traits in
        traits.displayScale = 2
        traits.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
      })
  }

  /// Cropped to the hero + week strip, not the whole device: proves the real
  /// `PracticeScreen`/`TabView` path (not a bare component) reflows at large
  /// text without needing a full-screen (and much larger) reference (#1730).
  private var practiceHeaderAxConfig: Snapshotting<UIViewController, UIImage> {
    .image(
      on: ViewImageConfig(
        safeArea: .zero, size: CGSize(width: 390, height: 1400), traits: .init(displayScale: 1)),
      perceptualPrecision: 0.98,
      traits: UITraitCollection { traits in
        traits.displayScale = 1
        traits.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
      })
  }

  /// Flat fills only: the reference stays byte-stable and cheap as lossless PNG.
  private static let page: UIImage = {
    let size = CGSize(width: 600, height: 850)
    return UIGraphicsImageRenderer(size: size).image { context in
      UIColor(white: 0.98, alpha: 1).setFill()
      context.fill(CGRect(origin: .zero, size: size))
      UIColor(white: 0.55, alpha: 1).setFill()
      for stave in 0..<5 {
        for line in 0..<5 {
          context.fill(
            CGRect(x: 60, y: 140 + stave * 130 + line * 12, width: 480, height: 2))
        }
      }
    }
  }()

  func testRootShell() {
    assertSnapshot(of: host(RootView()), as: config)
  }

  func testGlobalBanner() {
    let banners = ZStack {
      PaperBackground()
      VStack(spacing: 0) {
        GlobalBanner(message: "Couldn't delete that item.", onDismiss: {})
        GlobalBanner(message: "Storage unavailable · changes this session won't be saved.")
        Spacer()
      }
    }
    assertSnapshot(of: host(banners), as: config)
  }

  func testLibraryAddScreenWithError() {
    assertSnapshot(
      of: host(LibraryAddScreen(previewError: "A piece needs a composer.")), as: config)
  }

  func testLibraryEditScreenWithError() {
    assertSnapshot(
      of: host(LibraryEditScreen(item: .previewDetail, previewError: "A piece needs a composer.")),
      as: config)
  }

  func testLibraryScreen() {
    assertSnapshot(of: host(NavigationStack { LibraryScreen() }), as: config)
  }

  func testLibrarySplitViewEmptyDetail() {
    assertSnapshot(
      of: host(LibrarySplitView(), store: .previewLibrary), as: splitConfig)
  }

  /// The column line must stop below the top strip, not run past the tabs
  /// (#1682); see `LibrarySplitAlignmentTests` for header alignment.
  func testLibrarySplitViewWithSelection() {
    assertSnapshot(
      of: host(LibrarySplitView(previewSelection: "piece-1"), store: .previewLibrary),
      as: splitConfig)
  }

  func testLibraryScreenPopulated() {
    assertSnapshot(
      of: host(NavigationStack { LibraryScreen() }, store: .previewLibrary), as: config)
  }

  func testLibraryScreenPriorities() {
    assertSnapshot(
      of: host(NavigationStack { LibraryScreen() }, store: .previewLibraryPriorities), as: config)
  }

  func testLibraryScreenFiltered() {
    assertSnapshot(
      of: host(NavigationStack { LibraryScreen() }, store: .previewLibraryFiltered), as: config)
  }

  func testLibraryScreenSearching() {
    assertSnapshot(
      of: host(
        NavigationStack { LibraryScreen(previewSearch: "clair") },
        store: .previewLibrarySearching), as: config)
  }

  /// The browse controls have to give way at accessibility sizes, or the screen
  /// lays out wider than the device and shifts off its leading edge (#1470).
  func testLibraryScreenAccessibilityText() {
    assertSnapshot(
      of: host(NavigationStack { LibraryScreen() }, store: .previewLibrary), as: axConfig)
  }

  func testPracticeScreen() {
    // Pin the date: the refreshed empty state shows the (live) week strip, so an
    // unfixed `Date()` would shift the week day-to-day and flake.
    assertSnapshot(
      of: host(PracticeScreen(referenceDate: PracticeSessionView.previewReferenceDate)), as: config)
  }

  func testPracticeScreenPopulated() {
    assertSnapshot(
      of: host(
        PracticeScreen(referenceDate: PracticeSessionView.previewReferenceDate),
        store: .previewPractice), as: config)
  }

  func testPracticeScreenSuggestion() {
    assertSnapshot(
      of: host(
        PracticeScreen(referenceDate: PracticeSessionView.previewReferenceDate),
        store: .previewPracticeSuggestion), as: config)
  }

  /// Dismissed but the core still has one to offer: the plain hero carries a
  /// way back to it (#1618).
  func testPracticeScreenSuggestionDismissed() {
    assertSnapshot(
      of: host(
        PracticeScreen(
          referenceDate: PracticeSessionView.previewReferenceDate, suggestionDismissed: true),
        store: .previewPracticeSuggestion), as: config)
  }

  func testPracticeScreenPriorities() {
    assertSnapshot(
      of: host(
        PracticeScreen(referenceDate: PracticeSessionView.previewReferenceDate),
        store: .previewPracticePriorities), as: config)
  }

  func testPracticeScreenSuggestionPriorities() {
    assertSnapshot(
      of: host(
        PracticeScreen(referenceDate: PracticeSessionView.previewReferenceDate),
        store: .previewPracticeSuggestionPriorities), as: config)
  }

  /// Dismissed with something starred too: two secondaries (restore, then
  /// priorities) stack under the plain hero (#1618).
  func testPracticeScreenSuggestionDismissedPriorities() {
    assertSnapshot(
      of: host(
        PracticeScreen(
          referenceDate: PracticeSessionView.previewReferenceDate, suggestionDismissed: true),
        store: .previewPracticeSuggestionPriorities), as: config)
  }

  /// No star, no ladder step, never-marked wording: conditionals that can
  /// regress without the full screen moving.
  func testUpNextHeroNeverMarked() {
    assertSnapshot(
      of: host(upNextHeroCard(.previewFresh)),
      as: .image(
        perceptualPrecision: 0.98, size: CGSize(width: 390, height: 370),
        traits: .init(displayScale: 2)))
  }

  private func upNextHeroCard(_ suggestion: SuggestedSession) -> some View {
    UpNextHero(suggestion: suggestion, onStart: {}, onBuildOwn: {})
      .padding(IntradaSpacing.card)
      .background(IntradaColor.paperTop)
      .frame(width: 390)
  }

  func testRecoveryPromptCard() throws {
    // Component-level (not full-screen): the card is the load-bearing state and
    // the flat crop keeps the reference PNG well under the size ceiling (#840).
    let session = try XCTUnwrap(Store.previewPracticeRecovery.recoverableSession)
    let card = RecoveryPromptCard(
      session: session, referenceDate: PracticeSessionView.previewReferenceDate,
      onResume: {}, onDiscard: {}
    )
    .padding(IntradaSpacing.card)
    .background(IntradaColor.paperTop)
    .frame(width: 390)
    assertSnapshot(
      of: host(card),
      as: .image(
        perceptualPrecision: 0.98, size: CGSize(width: 390, height: 240),
        traits: .init(displayScale: 2)))
  }

  /// Proves the real `PracticeScreen` week strip — the paging `TabView`, not
  /// the animations-disabled static branch — sizes itself to its content
  /// rather than clipping the day numbers, since nothing pinned that height
  /// at large text before (#1730). Cropped to the header, not the full
  /// device, to stay well under the snapshot size ceiling.
  func testPracticeScreenWeekStripAccessibilitySize() {
    assertSnapshot(
      of: host(
        PracticeScreen(referenceDate: PracticeSessionView.previewReferenceDate),
        store: .previewPractice), as: practiceHeaderAxConfig)
  }

  func testPracticeScreenQuietDay() {
    // Open on Monday — a day with no practice — to lock the per-day empty state.
    let monday = PracticeWeek.days(
      containing: PracticeSessionView.previewReferenceDate, calendar: PreviewCalendar.utc)[0]
    assertSnapshot(
      of: host(
        PracticeScreen(
          referenceDate: PracticeSessionView.previewReferenceDate, selectedDay: monday),
        store: .previewPractice), as: config)
  }

  /// The read-only record of a past session (#1371), including the session
  /// mark #1012 asked for.
  func testPracticeSessionDetail() {
    assertSnapshot(
      of: host(
        NavigationStack {
          PracticeSessionDetailScreen(session: .previewCompleted)
        }, store: .previewPractice), as: config)
  }

  /// Skipped and not-played items, and no session mark to draw.
  func testPracticeSessionDetailEndedEarly() {
    assertSnapshot(
      of: host(
        NavigationStack {
          PracticeSessionDetailScreen(session: .previewEndedEarly)
        }, store: .previewPractice), as: config)
  }

  /// Pins the accessibility-size branch: the ring drops below the text so the
  /// meta line cannot break mid-word (#1471's shape, one screen over).
  func testPracticeSessionDetailAccessibilitySize() {
    let detail = NavigationStack {
      PracticeSessionDetailScreen(session: .previewCompleted)
    }
    .dynamicTypeSize(.accessibility3)
    assertSnapshot(of: host(detail, store: .previewPractice), as: config)
  }

  func testSessionBuilderEmpty() {
    assertSnapshot(of: host(NavigationStack { SessionBuilderScreen() }), as: config)
  }

  func testSessionBuilderPopulated() {
    assertSnapshot(
      of: host(NavigationStack { SessionBuilderScreen() }, store: .previewBuilding), as: config)
  }

  func testSessionBuilderGrouped() {
    assertSnapshot(
      of: host(NavigationStack { SessionBuilderScreen() }, store: .previewBuildingGrouped),
      as: config)
  }

  func testFocusPlayerWithTarget() {
    assertSnapshot(
      of: host(
        FocusPlayerScreen(referenceDate: ActiveSessionView.previewReferenceDate),
        store: .previewActive), as: config)
  }

  func testClickControlStates() {
    // Flat player paper, not the radial wash: the gradient is not what's under
    // test here and it is most of a reference's bytes (snapshot hygiene).
    let states = ZStack {
      IntradaColor.playerBgMid
      VStack(spacing: 32) {
        ClickControl(
          bpm: 66, isRunning: false, unavailable: false, atSeededTempo: true,
          targetDisplay: "Andante · ♩ = 66", targetSpoken: "Andante, 66 beats per minute",
          onToggle: {}, onStep: { _ in })
        ClickControl(
          bpm: 72, isRunning: true, unavailable: false, atSeededTempo: false,
          targetDisplay: "Andante · ♩ = 66", targetSpoken: "Andante, 66 beats per minute",
          onToggle: {}, onStep: { _ in })
        ClickControl(
          bpm: 96, isRunning: false, unavailable: false, atSeededTempo: true,
          targetDisplay: nil, targetSpoken: nil, onToggle: {}, onStep: { _ in })
        ClickControl(
          bpm: 96, isRunning: false, unavailable: true, atSeededTempo: true,
          targetDisplay: nil, targetSpoken: nil, onToggle: {}, onStep: { _ in })
      }
      .padding(.horizontal, IntradaSpacing.card)
    }
    assertSnapshot(of: host(states), as: config)
  }

  func testClickBarLineStates() {
    let states = ZStack {
      IntradaColor.playerBgMid
      VStack(spacing: 24) {
        ClickBarLine(
          metre: Metre(beats: 4, unit: 4, groups: nil), sounding: 0b1111, currentBeat: 1,
          onTap: {})
        ClickBarLine(
          metre: Metre(beats: 4, unit: 4, groups: nil), sounding: 0b1000, currentBeat: 3,
          onTap: {})
        ClickBarLine(
          metre: Metre(beats: 7, unit: 8, groups: [3, 2, 2]), sounding: 0b0101001,
          currentBeat: 0, onTap: {})
        ClickControl(
          bpm: 168, unit: 8, isRunning: true, unavailable: false, atSeededTempo: true,
          targetDisplay: nil, targetSpoken: nil, onToggle: {}, onStep: { _ in })
      }
      .padding(.horizontal, IntradaSpacing.card)
    }
    assertSnapshot(of: host(states), as: config)
  }

  func testClickSheetIrregularMetre() {
    let click = ClickController()
    click.reseed(target: 168, metre: Metre(beats: 7, unit: 8, groups: [3, 2, 2]))
    click.apply(.groupStarts)
    assertSnapshot(of: host(ClickSheet(click: click, bpm: 168)), as: config)
  }

  /// The sounding row is the tight one, so it is the state that has to reflow.
  func testClickControlLargeText() {
    let sounding = ZStack {
      IntradaColor.playerBgMid
      ClickControl(
        bpm: 208, isRunning: true, unavailable: false, atSeededTempo: false,
        targetDisplay: "Andante · ♩ = 66", targetSpoken: "Andante, 66 beats per minute",
        onToggle: {}, onStep: { _ in }
      )
      .padding(.horizontal, IntradaSpacing.card)
    }
    assertSnapshot(of: host(sounding), as: axConfig)
  }

  // A session past an hour, where the reading becomes `H:MM:SS` and outgrows the
  // orientation slot's minimum. Full-screen because the whole strip reflows.
  func testFocusPlayerLongSession() {
    assertSnapshot(
      of: host(
        FocusPlayerScreen(referenceDate: ActiveSessionView.previewReferenceDate),
        store: .previewActiveLongSession), as: config)
  }

  // Band-level rather than full-screen: what can regress is the slot clipping a
  // long clock, and a component reference costs a few KB against 300k+ for the
  // player's radial gradient (snapshot hygiene).
  private func orientationBand(elapsed: Int) -> some View {
    SessionOrientationBand(
      sessionElapsed: elapsed, positionLabel: "FOCUS · 3 OF 5",
      types: [.exercise, .exercise, .exercise, .piece, .exercise], filled: 3,
      menu: { Image(systemName: "ellipsis").frame(width: 28, height: 28) }
    )
    .frame(width: 342)
    .padding(IntradaSpacing.card)
    .background(IntradaColor.playerBgMid)
  }

  func testOrientationBandLongSession() {
    assertSnapshot(of: orientationBand(elapsed: 3732), as: .image(precision: 0.99))
  }

  func testOrientationBandLargeText() {
    assertSnapshot(
      of: orientationBand(elapsed: 3732),
      as: .image(
        precision: 0.99,
        traits: UITraitCollection { traits in
          traits.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        }))
  }

  func testFocusPlayerWithReps() {
    assertSnapshot(
      of: host(
        FocusPlayerScreen(referenceDate: ActiveSessionView.previewReferenceDate),
        store: .previewActiveReps), as: config)
  }

  func testSessionSummaryCompleted() {
    assertSnapshot(of: host(SessionSummaryScreen(), store: .previewSummary), as: config)
  }

  func testSessionSummaryWithReflection() {
    assertSnapshot(
      of: host(SessionSummaryScreen(), store: .previewSummaryWithReflection), as: config)
  }

  func testSessionSummaryEndedEarly() {
    assertSnapshot(
      of: host(SessionSummaryScreen(), store: .previewSummaryEndedEarly), as: config)
  }

  func testRoutinesScreen() {
    assertSnapshot(of: host(RoutinesScreen()), as: config)
  }

  func testAnalyticsScreen() {
    assertSnapshot(of: host(AnalyticsScreen()), as: config)
  }

  func testProgressScreenPopulated() {
    assertSnapshot(of: host(AnalyticsScreen(), store: .previewProgress), as: config)
  }

  func testLibraryScreenMastery() {
    assertSnapshot(
      of: host(NavigationStack { LibraryScreen() }, store: .previewLibraryMastery), as: config)
  }

  // ── Engaging-refresh components ──

  func testScoreRing() {
    let rings = ZStack {
      PaperBackground()
      HStack(spacing: 18) {
        ScoreRing(score: nil)
        ForEach([1, 4, 7, 10], id: \.self) { ScoreRing(score: $0) }
      }
      .padding(16)
    }
    assertSnapshot(of: host(rings), as: config)
  }

  func testScoreRingHero() {
    let hero = ZStack {
      PaperBackground()
      HStack(spacing: 24) {
        ScoreRing(score: 7, size: 132, showsScale: true)
        ScoreRing(score: nil, size: 132, showsScale: true)
      }
      .padding(16)
    }
    assertSnapshot(of: host(hero), as: config)
  }

  func testScoreSelectorPills() {
    let selectors = ZStack {
      PaperBackground()
      VStack(spacing: 20) {
        ScoreSelector(score: 0, accessibilityLabel: "Score") { _ in }
        ScoreSelector(score: 4, accessibilityLabel: "Score") { _ in }
        ScoreSelector(score: 10, accessibilityLabel: "Score") { _ in }
      }
      .padding(16)
    }
    assertSnapshot(of: host(selectors), as: config)
  }

  func testRecentSessions() {
    let block = ZStack {
      PaperBackground()
      RecentSessions(sessions: [
        RecentSession(id: "1", score: 7, dateText: "Tue · Jun 24"),
        RecentSession(id: "2", score: 6, dateText: "Sat · Jun 21"),
        RecentSession(id: "3", score: 5, dateText: "Wed · Jun 18"),
      ])
      .padding(16)
    }
    assertSnapshot(of: host(block), as: config)
  }

  func testRecentSessionsDeclining() {
    let block = ZStack {
      PaperBackground()
      RecentSessions(sessions: [
        RecentSession(id: "1", score: 5, dateText: "Tue · Jun 24"),
        RecentSession(id: "2", score: 6, dateText: "Sat · Jun 21"),
        RecentSession(id: "3", score: 8, dateText: "Wed · Jun 18"),
      ])
      .padding(16)
    }
    assertSnapshot(of: host(block), as: config)
  }

  func testAddRowButtonVariants() {
    let buttons = ZStack {
      PaperBackground()
      VStack(spacing: 16) {
        AddRowButton(title: "Add a related exercise") {}
        AddRowButton(title: "Add a related exercise", style: .plain) {}
      }
      .padding(16)
    }
    assertSnapshot(of: host(buttons), as: config)
  }

  func testReflectionSheet() {
    let sheet = ZStack(alignment: .bottom) {
      PaperBackground()
      ReflectionSheet(
        itemTitle: "Scales · D♭", elapsedDisplay: "7:00", tempoTarget: nil,
        onSave: { _ in }, onSkip: {})
    }
    assertSnapshot(of: host(sheet), as: config)
  }

  func testReflectionSheetWithTempoTarget() {
    let sheet = ZStack(alignment: .bottom) {
      PaperBackground()
      ReflectionSheet(
        itemTitle: "Scales · D♭", elapsedDisplay: "7:00", tempoTarget: 96,
        onSave: { _ in }, onSkip: {})
    }
    assertSnapshot(of: host(sheet), as: config)
  }

  // #1083 C2: Step picker, pre-selected to the current (not-yet-solid) step.
  func testReflectionSheetWithStepPicker() {
    let sheet = ZStack(alignment: .bottom) {
      PaperBackground()
      ReflectionSheet(
        itemTitle: "ii–V–i Enclosures", elapsedDisplay: "7:00", tempoTarget: nil,
        variants: LibraryItemView.previewExerciseWithSteps.variants,
        currentVariantId: LibraryItemView.previewExerciseWithSteps.variants.first(
          where: \.isCurrent
        )?.id,
        onSave: { _ in }, onSkip: {})
    }
    assertSnapshot(of: host(sheet), as: config)
  }

  func testMasteryDial() {
    let dial = ZStack {
      PaperBackground()
      MasteryDial(value: 3.4)
    }
    assertSnapshot(of: host(dial), as: config)
  }

  func testMasteryDeltaRows() {
    let rows = ZStack {
      PaperBackground()
      VStack(spacing: 12) {
        MasteryDelta(
          title: "Clair de Lune", subtitle: "D♭ major · now", was: 3, now: 4, kind: .piece)
        MasteryDelta(
          title: "Hanon No. 1", subtitle: "first time marked", was: nil, now: 3, kind: .exercise)
        MasteryDeltaToast(
          title: "Clair de Lune moved up", subtitle: "D♭ major mastery", was: 3, now: 4)
      }
      .padding(16)
    }
    assertSnapshot(of: host(rows), as: config)
  }

  func testConsistencyBars() {
    let bars = ZStack {
      PaperBackground()
      ConsistencyBars(weeks: [
        ConsistencyWeek(label: "W1", minutes: 40),
        ConsistencyWeek(label: "W2", minutes: 75),
        ConsistencyWeek(label: "W3", minutes: 55),
        ConsistencyWeek(label: "W4", minutes: 95),
        ConsistencyWeek(label: "Now", minutes: 82, isCurrent: true),
      ])
      .padding(16)
    }
    assertSnapshot(of: host(bars), as: config)
  }

  /// Recorded at the size #1471 reports, which is also where the ring's clamp
  /// binds hardest: stacked layout and dial inset are both load-bearing here.
  func testMasteryHeroCardAccessibilitySize() {
    let hero = ZStack {
      PaperBackground()
      MasteryHeroCard(mastery: 6.4, monthDelta: 1.2, itemsCovered: 5)
        .padding(16)
    }
    .dynamicTypeSize(.accessibility5)
    assertSnapshot(of: host(hero), as: config)
  }

  func testRepCounter() {
    let counters = ZStack {
      PaperBackground()
      VStack(spacing: 24) {
        RepCounter(
          count: 0, slots: 10, touched: false, reached: false, onGotIt: {}, onNotQuite: {})
        RepCounter(
          count: 7, slots: 10, touched: true, reached: false, onGotIt: {}, onNotQuite: {})
        RepCounter(
          count: 10, slots: 10, touched: true, reached: true, onGotIt: {}, onNotQuite: {})
      }
      .padding(16)
    }
    assertSnapshot(of: host(counters), as: config)
  }

  func testRepCounterAccessibilitySize() {
    let counter = ZStack {
      PaperBackground()
      RepCounter(
        count: 3, slots: 10, touched: true, reached: false, onGotIt: {}, onNotQuite: {}
      )
      .padding(16)
    }
    .dynamicTypeSize(.accessibility3)
    assertSnapshot(of: host(counter), as: config)
  }

  func testLibraryDetailScreen() {
    // Preset path so the snapshot covers the real navigation chrome (back
    // chevron + transparent bar over the serif title), not just the body.
    let store = Store(bridge: PreviewBridge(items: [.previewDetail]))
    let pushed = NavigationStack(path: .constant([LibraryItemView.previewDetail.id])) {
      LibraryScreen()
    }
    assertSnapshot(of: host(pushed, store: store), as: config)
  }

  /// The chord-chart card: parsed bar grid + "See the curriculum" (Phase A).
  func testLibraryDetailChordChartCard() {
    let store = Store(bridge: PreviewBridge(items: [.previewCharted]))
    let pushed = NavigationStack(path: .constant([LibraryItemView.previewCharted.id])) {
      LibraryScreen()
    }
    assertSnapshot(of: host(pushed, store: store), as: config)
  }

  /// The photo card in both of its load-bearing states (#1355). Component-level
  /// rather than another whole-screen reference: the card is what changes, and
  /// the two states are the only thing that can independently regress.
  func testPhotoCardStates() {
    let cards = ZStack {
      PaperBackground()
      VStack(spacing: 16) {
        PhotoCard(itemId: "p1", photoId: nil)
        PhotoCard(itemId: "p1", photoId: "01ARZ3NDEKTSV4RRFFQ69G5FAV") { _ in Self.page }
      }
      .padding(16)
    }
    assertSnapshot(of: host(cards), as: config)
  }

  /// The selectable derived-curriculum commit sheet, with already-linked (not
  /// selectable) + fallback flags and per-row selection controls.
  func testScaffoldPreviewSheet() {
    assertSnapshot(
      of: host(ScaffoldPreviewSheet(preview: .preview, onCommit: { _ in })), as: config)
  }

  func testPieceDetailLinkedPopulated() {
    let store = Store(bridge: PreviewBridge(items: [.previewDetailWithLinkedExercises]))
    let pushed = NavigationStack(
      path: .constant([LibraryItemView.previewDetailWithLinkedExercises.id])
    ) { LibraryScreen() }
    assertSnapshot(of: host(pushed, store: store), as: config)
  }

  func testPieceDetailLinkedEmpty() {
    let store = Store(bridge: PreviewBridge(items: [.previewDetailLinkedEmpty]))
    let pushed = NavigationStack(
      path: .constant([LibraryItemView.previewDetailLinkedEmpty.id])
    ) { LibraryScreen() }
    assertSnapshot(of: host(pushed, store: store), as: config)
  }

  func testPieceDetailLinkedEditing() {
    let store = Store(bridge: PreviewBridge(items: [.previewDetailWithLinkedExercises]))
    // editingLinks is @State — seed via EditingLinkedExercisesWrapper with startEditingLinks=true.
    let editing = EditingLinkedExercisesWrapper(item: .previewDetailWithLinkedExercises)
    assertSnapshot(of: host(editing, store: store), as: config)
  }

  // #1363: linked to pieces it has never been practised with — every row shows
  // the ring's unrated rest, so a fresh link never reads as a bad score.
  func testExerciseDetailUsedInLinkedOnly() {
    let store = Store(bridge: PreviewBridge(items: [.previewExerciseLinkedOnly]))
    let pushed = NavigationStack(
      path: .constant([LibraryItemView.previewExerciseLinkedOnly.id])
    ) { LibraryScreen() }
    assertSnapshot(of: host(pushed, store: store), as: config)
  }

  // #1087 B2 / #1363: overall-ring caption + "Used in" rows — linked and
  // practised, practised only, linked only, removed, and on its own.
  func testExerciseDetailUsedIn() {
    let store = Store(bridge: PreviewBridge(items: [.previewExerciseUsedIn]))
    let pushed = NavigationStack(
      path: .constant([LibraryItemView.previewExerciseUsedIn.id])
    ) { LibraryScreen() }
    assertSnapshot(of: host(pushed, store: store), as: config)
  }

  // #1083 C2/C3: Steps section empty state — key-preset buttons + custom-steps link.
  func testExerciseDetailStepsEmptyState() {
    let store = Store(bridge: PreviewBridge(items: [.previewExercise]))
    let pushed = NavigationStack(
      path: .constant([LibraryItemView.previewExercise.id])
    ) { LibraryScreen() }
    assertSnapshot(of: host(pushed, store: store), as: config)
  }

  // #1083 C4: Steps edit mode — drag handle, inline rename field, remove button.
  func testExerciseDetailStepsEditing() {
    let store = Store(bridge: PreviewBridge(items: [.previewExerciseWithSteps]))
    let editing = EditingStepsWrapper(item: .previewExerciseWithSteps)
    assertSnapshot(of: host(editing, store: store), as: config)
  }

  // #1083 C2: Steps section — solid / current / unrated ring states, horizontal
  // scroller, "N of M solid" header; Key/Tempo rows hidden for laddered exercises.
  func testExerciseDetailWithSteps() {
    let store = Store(bridge: PreviewBridge(items: [.previewExerciseWithSteps]))
    let pushed = NavigationStack(
      path: .constant([LibraryItemView.previewExerciseWithSteps.id])
    ) { LibraryScreen() }
    assertSnapshot(of: host(pushed, store: store), as: config)
  }

  /// Largest accessibility text size — proves the Steps scroller reflows
  /// rather than clipping or wrapping (#1083 C2).
  func testExerciseDetailWithStepsAccessibilitySize() {
    let store = Store(bridge: PreviewBridge(items: [.previewExerciseWithSteps]))
    let pushed = NavigationStack(
      path: .constant([LibraryItemView.previewExerciseWithSteps.id])
    ) { LibraryScreen() }
    assertSnapshot(of: host(pushed, store: store), as: axConfig)
  }

  // #1083 C2: 12-step ladder — survives max realistic length without wrapping.
  func testExerciseDetailWith12Steps() {
    let store = Store(bridge: PreviewBridge(items: [.previewExerciseWithFullLadder]))
    let pushed = NavigationStack(
      path: .constant([LibraryItemView.previewExerciseWithFullLadder.id])
    ) { LibraryScreen() }
    assertSnapshot(of: host(pushed, store: store), as: config)
  }

  // #1083 C2: minimal step-list creation sheet, opened from the "+ Add steps" link.
  func testAddStepsSheet() {
    assertSnapshot(of: host(AddStepsSheet(itemId: "exercise-1")), as: config)
  }

  func testLibraryAddScreen() {
    assertSnapshot(of: host(LibraryAddScreen()), as: config)
  }

  func testLibraryAddScreenExercise() {
    assertSnapshot(of: host(LibraryAddScreen(defaultKind: .exercise)), as: config)
  }

  func testLibraryAddScreenStaged() {
    let form = ItemFormModel(kind: .piece)
    form.title = "Alice in Wonderland"
    form.composer = "Sammy Fain"
    form.chartText = "[A]\n| Dm7 | G7 | Cmaj7 | A7alt |\n| Dm7 | G7 | Cmaj7 | Cmaj7 |"
    form.stagedExercises = [
      .draft(
        id: UUID(), title: "Guide tones, ii to V to I", key: "C", modality: .major, bpm: "80"),
      .existing(id: "ex-1", title: "Shell voicings", meta: "C major"),
    ]
    assertSnapshot(of: host(LibraryAddScreen(previewForm: form)), as: config)
  }

  /// #1595: the banner says what, the field says where. The wash and the
  /// recoloured label are the whole treatment, so a pixel diff is what holds
  /// them.
  func testLibraryAddScreenMarksTheFieldAtFault() {
    let form = ItemFormModel(kind: .piece)
    form.title = "Alice in Wonderland"
    form.formError = "Composer must be between 1 and 200 characters"
    form.mark(.piece(field: .composer))
    assertSnapshot(of: host(LibraryAddScreen(previewForm: form)), as: config)
  }

  /// #1595: the whole form with a chart staged and two rows, the second one
  /// marked. This is what holds the wiring from the target the core sent to the
  /// row and section that carry it, which the component snapshots cannot see.
  func testLibraryAddScreenMarksTheStagedRowInContext() {
    let form = ItemFormModel(kind: .piece)
    form.title = "Alice in Wonderland"
    form.composer = "Sammy Fain"
    form.chartText = "| Dm7 | G7 | Cmaj7 | A7alt |"
    form.stagedExercises = [
      .existing(id: "ex-1", title: "Shell voicings", meta: "C major"),
      .draft(id: UUID(), title: "Untitled", key: "C", modality: .major, bpm: "80"),
    ]
    form.formError = "Title must be between 1 and 500 characters"
    form.mark(.exercise(index: 1, field: .title))
    assertSnapshot(of: host(LibraryAddScreen(previewForm: form)), as: tallFormConfig)
  }

  /// #1436: the composer was read weakly, so its mark's glyph is dimmed
  /// (#1458: the label itself stays at `inkSecondary`), and a pixel diff can
  /// hold that.
  func testLibraryAddScreenReadFromAPhoto() {
    assertSnapshot(of: host(addForm(from: .readPage)), as: config)
  }

  /// The mark clears on the keystroke, not on submit: the composer is the
  /// user's from the moment they correct it.
  func testLibraryAddScreenAfterEditingAReadField() {
    let form = ItemFormModel(kind: .piece)
    form.fill(from: .readPage)
    form.composer = "Joseph Kosma"
    assertSnapshot(of: host(addForm(form)), as: config)
  }

  /// A read that failed, or one the device could not run, must not render
  /// identically to one that worked.
  func testScanPageEntryStates() {
    let stub = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 80)).image { context in
      UIColor(IntradaColor.surfaceSunken).setFill()
      context.fill(CGRect(origin: .zero, size: CGSize(width: 60, height: 80)))
    }
    let states: [(PhotoRecognitionStatus, Bool)] = [
      (.idle, false), (.reading, false), (.ready, false), (.ready, true),
      (.failed, false), (.unsupported, false),
    ]
    let stack = VStack(spacing: IntradaSpacing.card) {
      ForEach(Array(states.enumerated()), id: \.offset) { _, state in
        ScanPageEntry(
          photoId: state.0 == .idle ? nil : "01JB0000000000000000000000",
          status: state.0, readNothing: state.1, onCaptured: { _ in },
          loadImage: { _ in stub })
      }
    }
    .padding(IntradaSpacing.card)
    .frame(width: 390)
    .background(PaperBackground())

    assertSnapshot(of: stack, as: .image(layout: .sizeThatFits))
  }

  /// #1595: the row the refused save named wears the wash and a danger bar in
  /// place of its kind bar, and only that row does.
  func testDraftItemRowAtFault() {
    let rows = VStack(spacing: 0) {
      DraftItemRow(title: "Shell voicings", meta: "C major", onRemove: {})
      HairlineDivider()
      DraftItemRow(
        title: "Untitled", meta: nil, faulted: true, faultedField: .title, onRemove: {})
    }
    .background(IntradaColor.cardFill)
    .padding(IntradaSpacing.card)
    .frame(width: 390)
    .background(PaperBackground())

    assertSnapshot(of: rows, as: .image(layout: .sizeThatFits))
  }

  /// #1595: a refused bar puts a danger edge on the chart block, the one thing
  /// that changes on a chart the shell cannot parse.
  func testStagedChartCardAtFault() {
    let card = VStack(spacing: IntradaSpacing.card) {
      StagedChartCard(
        text: "| Dm7 | G7 | Hxyz | Cmaj7 |", readWeakly: nil, faulted: true,
        faultedBarNumber: 3, onEdit: {}
      )
      .cardSurface()
      StagedChartCard(
        text: "| Dm7 | G7 | Cmaj7 | A7alt |", readWeakly: nil, onEdit: {}
      )
      .cardSurface()
    }
    .padding(IntradaSpacing.card)
    .frame(width: 390)
    .background(PaperBackground())

    assertSnapshot(of: card, as: .image(layout: .sizeThatFits))
  }

  func testDraftItemRows() {
    let rows = VStack(spacing: 0) {
      DraftItemRow(title: "Guide tones, ii to V to I", meta: "C major · 80 bpm", onRemove: {})
      HairlineDivider()
      DraftItemRow(title: "Shell voicings", meta: "C major", onRemove: {})
      HairlineDivider()
      DraftItemRow(title: "No key or tempo yet", meta: nil, onRemove: {})
    }
    .background(IntradaColor.cardFill)
    .padding(IntradaSpacing.card)
    .frame(width: 390)
    .background(PaperBackground())

    assertSnapshot(of: rows, as: .image(layout: .sizeThatFits))
  }

  private func addForm(from draft: PhotoDraft) -> some View {
    let form = ItemFormModel(kind: .piece)
    form.fill(from: draft)
    return addForm(form)
  }

  private func addForm(_ form: ItemFormModel) -> some View {
    ItemFormScaffold(
      form: form, title: "New Piece", confirmLabel: "Add", composerSuggestions: [],
      tagSuggestions: []
    ) {}
  }

  func testLibraryEditScreen() {
    assertSnapshot(of: host(LibraryEditScreen(item: .previewDetail)), as: config)
  }

  func testLibraryEditScreenExercise() {
    assertSnapshot(of: host(LibraryEditScreen(item: .previewExercise)), as: config)
  }

  func testTypeBadges() {
    let badges = ZStack {
      PaperBackground()
      HStack(spacing: 12) {
        TypeBadge(kind: .piece)
        TypeBadge(kind: .exercise)
      }
    }
    assertSnapshot(of: host(badges), as: config)
  }

  func testKeyPickerCollapsed() {
    let pickers = ZStack {
      PaperBackground()
      VStack(spacing: 16) {
        VStack(spacing: 0) {
          KeyPicker(label: "Key", key: .constant(""), modality: .constant(nil))
        }.cardSurface()
        VStack(spacing: 0) {
          KeyPicker(label: "Key", key: .constant("Gb"), modality: .constant(.major))
        }.cardSurface()
      }
      .padding(16)
    }
    assertSnapshot(of: host(pickers), as: config)
  }

  func testKeyPickerExpandedEmpty() {
    let picker = ZStack {
      PaperBackground()
      VStack(spacing: 0) {
        KeyPicker(
          label: "Key", key: .constant(""), modality: .constant(nil), initiallyExpanded: true)
      }
      .cardSurface()
      .padding(16)
    }
    assertSnapshot(of: host(picker), as: config)
  }

  func testKeyPickerExpandedEnharmonic() {
    let picker = ZStack {
      PaperBackground()
      VStack(spacing: 0) {
        KeyPicker(
          label: "Key", key: .constant("Gb"), modality: .constant(.major), initiallyExpanded: true)
      }
      .cardSurface()
      .padding(16)
    }
    assertSnapshot(of: host(picker), as: config)
  }

  func testAutocompleteField() {
    let pool = ["Bach", "Beethoven", "Brahms", "Chopin", "Debussy"]
    let fields = ZStack {
      PaperBackground()
      VStack(spacing: 16) {
        VStack(spacing: 0) {
          AutocompleteField(
            label: "Composer", text: .constant("B"), suggestions: pool,
            initiallyShowingSuggestions: true)
        }.cardSurface()
        VStack(spacing: 0) {
          AutocompleteField(label: "Composer", text: .constant("Ravel"), suggestions: pool)
        }.cardSurface()
      }
      .padding(16)
    }
    assertSnapshot(of: host(fields), as: config)
  }

  func testTagChipInput() {
    let pool = ["classical", "recital", "jazz", "warm-up", "technique", "etude"]
    let fields = ZStack {
      PaperBackground()
      VStack(spacing: 16) {
        VStack(spacing: 0) {
          TagChipInput(
            label: "Tags", tags: .constant(["classical", "recital"]), suggestions: pool,
            initiallyShowingSuggestions: true)
        }.cardSurface()
        VStack(spacing: 0) {
          TagChipInput(label: "Tags", tags: .constant([]), suggestions: pool)
        }.cardSurface()
      }
      .padding(16)
    }
    assertSnapshot(of: host(fields), as: config)
  }

  func testAddToSessionSheet() {
    assertSnapshot(of: host(AddToSessionSheet(), store: .previewBuilding), as: config)
  }

  func testAddToSessionSheetRecentlyPractised() {
    assertSnapshot(
      of: host(AddToSessionSheet(), store: .previewBuildingRecentlyPractised), as: config)
  }

  func testAddToSessionSheetRecentlyPractisedHiddenWhileFiltered() {
    assertSnapshot(
      of: host(AddToSessionSheet(), store: .previewBuildingRecentlyPractisedFiltered), as: config)
  }

  func testSessionBuilderGroupedEditing() {
    // editMode is @State — seed via the startInEditMode init to capture the
    // nested-row reorder/remove/settings controls without UI interaction.
    assertSnapshot(
      of: host(
        NavigationStack { SessionBuilderScreen(startInEditMode: true) },
        store: .previewBuildingGrouped), as: config)
  }

  func testAddRelatedExerciseSheet() {
    assertSnapshot(
      of: host(
        AddRelatedExerciseSheet(groupId: "g1"), store: .previewBuildingGrouped),
      as: config)
  }

  func testAddRelatedExerciseSheetAdded() {
    assertSnapshot(
      of: host(
        AddRelatedExerciseSheet(groupId: "g1"), store: .previewBuildingGroupedAdded),
      as: config)
  }

  func testEntrySettingsSheetEmpty() {
    assertSnapshot(
      of: host(EntrySettingsSheet(entry: .previewGroupedScales), store: .previewBuildingGrouped),
      as: config)
  }

  func testEntrySettingsSheetPopulated() {
    assertSnapshot(
      of: host(
        EntrySettingsSheet(entry: .previewGroupedScalesConfigured), store: .previewBuildingGrouped
      ), as: config)
  }

  func testTagFilterSheet() {
    let sheet = TagFilterSheet(
      available: ["classical", "jazz", "recital", "technique", "warm-up"],
      selected: ["jazz", "recital"],
      onChange: { _ in })
    assertSnapshot(of: host(sheet), as: config)
  }

  func testTagFilterSheetEmpty() {
    let sheet = TagFilterSheet(available: [], selected: [], onChange: { _ in })
    assertSnapshot(of: host(sheet), as: config)
  }

  func testLinkedExercisePicker() {
    // Three exercises; the first is already related (pre-selected → check), the
    // rest show the outlined add control.
    let sheet = LinkedItemPickerSheet(
      kind: .exercise,
      available: [
        .previewExercise,
        LibraryItemView(
          id: "exercise-2", itemType: .exercise, title: "Db Major Scale", subtitle: "",
          key: "Db", modality: .major, tempo: nil, tempoMarking: nil, tempoBpm: nil,
          notes: nil, tags: [], createdAt: "", updatedAt: "", practice: nil,
          latestAchievedTempo: nil, priority: false, linkedExercises: [],
          usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil, variants: [],
          ladderIsKeys: false,
          photoId: nil),
        LibraryItemView(
          id: "exercise-3", itemType: .exercise, title: "Arpeggios in Db", subtitle: "",
          key: nil, modality: nil, tempo: nil, tempoMarking: nil, tempoBpm: nil,
          notes: nil, tags: [], createdAt: "", updatedAt: "", practice: nil,
          latestAchievedTempo: nil, priority: false, linkedExercises: [],
          usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil, variants: [],
          ladderIsKeys: false,
          photoId: nil),
      ],
      linkedIds: ["exercise-1"],
      onApply: { _, _ in })
    assertSnapshot(of: host(sheet), as: config)
  }

  // #1616: the create trigger plus a drafted row, alongside the ordinary list.
  func testLinkedExercisePickerWithDraft() {
    let sheet = LinkedItemPickerSheet(
      kind: .exercise,
      available: [.previewExercise],
      linkedIds: [],
      existingDrafts: [
        .draft(
          id: UUID(), title: "Guide tones, ii to V to I", key: "C", modality: .major, bpm: "80")
      ],
      onApply: { _, _ in })
    assertSnapshot(of: host(sheet), as: config)
  }

  func testLinkedPiecePicker() {
    let sheet = LinkedItemPickerSheet(
      kind: .piece,
      available: [.previewPiece, piece(id: "piece-9", "Blue Bossa", "Kenny Dorham")],
      linkedIds: [LibraryItemView.previewPiece.id],
      onApply: { _, _ in })
    assertSnapshot(of: host(sheet), as: config)
  }

  // #1363: the card framed on its own — the screen snapshots above cut off
  // before it — with every row state in one reference.
  func testUsedInCardRowStates() {
    assertSnapshot(
      of: usedInCard(LibraryItemView.previewExerciseUsedIn.usedIn), as: config)
  }

  // #1363: at the largest text size the Link row has to reflow, not clip — it
  // carries a ring, two lines of text, a button and a chevron across one width.
  func testUsedInCardRowStatesAccessibilityText() {
    assertSnapshot(
      of: usedInCard(LibraryItemView.previewExerciseUsedIn.usedIn), as: axConfig)
  }

  func testUsedInCardOnItsOwn() {
    assertSnapshot(of: usedInCard([]), as: config)
  }

  private func piece(id: String, _ title: String, _ composer: String) -> LibraryItemView {
    LibraryItemView(
      id: id, itemType: .piece, title: title, subtitle: composer, key: nil, modality: nil,
      tempo: nil, tempoMarking: nil, tempoBpm: nil, notes: nil, tags: [], createdAt: "",
      updatedAt: "", practice: nil, latestAchievedTempo: nil, priority: false,
      linkedExercises: [], usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil,
      variants: [],
      ladderIsKeys: false, photoId: nil)
  }

  private func usedInCard(_ usage: [ExerciseUsageView]) -> UIViewController {
    // Hosted in a NavigationStack: outside one the rows' NavigationLinks render
    // disabled, which greys the whole row and makes the reference a lie.
    host(
      NavigationStack {
        ZStack {
          PaperBackground()
          ScrollView {
            UsedInCard(
              usage: usage, locale: Locale(identifier: "en_US"),
              calendar: PreviewCalendar.utc, onLink: { _ in }, onLinkAPiece: {}
            )
            .padding(IntradaSpacing.card)
          }
        }
      })
  }

  func testLibraryItemCards() {
    var manyTags = LibraryItemView.previewDetail
    manyTags.tags = ["jazz", "improv", "bebop", "ii-V-I", "comping"]
    // Starred: pins the accent star to the left of the tags + the trailing meter.
    var starred = LibraryItemView.previewDetail
    starred.priority = true
    let cards = ZStack {
      PaperBackground()
      VStack(spacing: 14) {
        LibraryItemCard(item: .previewPiece)
        LibraryItemCard(item: .previewDetail)
        LibraryItemCard(item: manyTags)  // 5 tags → +2 overflow pill
        LibraryItemCard(item: starred, showsMastery: true)
        LibraryItemCard(item: .previewExerciseWithFullLadder)
        LibraryItemCard(item: .previewExerciseWithStepLadder)
        // No composer, key or tempo: the prompt fills the metadata slot
        // rather than the card collapsing to one ragged line (#1734).
        LibraryItemCard(item: .previewMinimal, showsMastery: true)
      }
      .padding(16)
    }
    // tallFormConfig, not config: seven cards run past an iPhone 13's fold,
    // and the device-sized frame was cropping the last one out of frame.
    assertSnapshot(of: host(cards), as: tallFormConfig)
  }

  /// Both tempo-trend states in one frame: the plot with two breaks in the line
  /// where sessions measured nothing, and the too-little-to-plot line beneath.
  func testTempoTrend() {
    let trends = ZStack {
      PaperBackground()
      VStack(spacing: 14) {
        TempoTrend(display: .previewWithGaps)
        TempoTrend(display: .previewSingleMeasurement)
      }
      .padding(16)
    }
    assertSnapshot(of: host(trends), as: config)
  }

  /// At accessibility sizes the footer keeps the measured count and drops the
  /// end dates, rather than crushing three labels into one row.
  func testTempoTrendAccessibilityText() {
    let trend = ZStack {
      PaperBackground()
      TempoTrend(display: .previewWithGaps).padding(16)
    }
    assertSnapshot(of: host(trend), as: axConfig)
  }

  /// The four states a simulator can reach. There is no camera on one, so the
  /// live preview and the capture itself are only checkable on a device
  /// (#1460); what these pin is that the chrome over the backdrop stays legible
  /// and laid out.
  func testPageCameraStates() {
    let states = ZStack {
      IntradaColor.viewerBackdrop
      VStack(spacing: 24) {
        PageCameraShutter(disabled: false, onPress: {})
        PageCameraFailure(message: "Couldn't take the photo. Try again.")
        PageCameraBlocked(access: .denied, onOpenSettings: {})
        PageCameraUnstartable()
      }
    }
    assertSnapshot(of: host(states), as: config)
  }

  /// The confirm step, which is the fix: the page you approve is the page that
  /// gets stored, where the scanner kept one shot of several without saying so.
  func testPageCameraConfirm() {
    let confirm = ZStack {
      IntradaColor.viewerBackdrop
      CapturedPageConfirm(page: Self.page, onKeep: {}, onRetake: {})
        .padding(16)
    }
    assertSnapshot(of: host(confirm), as: config)
  }

  /// Every instrument icon at its three sizes (#1693): a missing or empty
  /// asset renders blank here rather than on a device.
  func testInstrumentIcons() {
    let sheet = VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      ForEach(InstrumentIcon.all, id: \.self) { icon in
        HStack(spacing: IntradaSpacing.card) {
          InstrumentGlyph(icon: icon, size: IntradaGlyph.bar)
          InstrumentGlyph(icon: icon, size: IntradaGlyph.tile)
          InstrumentGlyph(icon: icon, size: IntradaGlyph.hero)
          Text(icon.tileLabel).font(IntradaFont.body)
        }
      }
    }
    .foregroundStyle(IntradaColor.ink)
    .padding(IntradaSpacing.card)
    assertSnapshot(of: host(sheet), as: tallFormConfig)
  }

  // ── Profile ─────────────────────────────────────────────────────────

  func testProfileScreen() {
    assertSnapshot(
      of: host(NavigationStack { ProfileScreen() }, store: .previewProfile), as: config)
  }

  /// No name yet: a prompt to add one, not blank rows (#1692).
  func testProfileScreenEmpty() {
    assertSnapshot(of: host(NavigationStack { ProfileScreen() }), as: config)
  }

  func testProfileEditSheet() {
    assertSnapshot(of: host(ProfileEditSheet(), store: .previewProfile), as: config)
  }

  func testProfileEditSheetWithError() {
    assertSnapshot(
      of: host(
        ProfileEditSheet(
          previewError: "Name must be 100 characters or fewer", field: .name),
        store: .previewProfile),
      as: config)
  }

  func testInstrumentIconPicker() {
    assertSnapshot(
      of: host(InstrumentIconPicker(suggested: .cello, choice: .constant(.harp))), as: config)
  }

  /// The greeting leads the subtitle and the badge is the way in (#1694, T25).
  func testPracticeScreenGreeting() {
    assertSnapshot(
      of: host(
        PracticeScreen(referenceDate: PracticeSessionView.previewReferenceDate),
        store: .previewPracticeProfile), as: config)
  }

  /// The eight highlighters through the environment (#1677): a marker surface
  /// wears whichever swatch the root sets, not the butter token.
  func testHighlighterColours() {
    let colours: [HighlighterColour] = [
      .butter, .coral, .mint, .sky, .lavender, .sage, .peach, .powder,
    ]
    let sheet = VStack(spacing: IntradaSpacing.cardCompact) {
      ForEach(colours, id: \.self) { colour in
        BrandBarButton(action: {}) { Text(String(describing: colour)) }
          .environment(\.marker, IntradaColor.marker(colour))
      }
    }
    .padding(IntradaSpacing.card)
    assertSnapshot(of: host(sheet), as: config)
  }
}
