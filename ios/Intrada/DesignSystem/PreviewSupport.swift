#if DEBUG
  import Foundation
  import IntradaCoreFFI
  import SharedTypes

  extension TempoTrendDisplay {
    /// Nine sessions, seven measured: two breaks in the line, one of them two
    /// sessions wide.
    static let previewWithGaps = make([88, 92, 96, nil, 100, 104, nil, 108, 116])
    /// One measurement, which is less than a trend.
    static let previewSingleMeasurement = make([108])

    /// Built through the shipped mapping, so a fixture cannot drift from what
    /// the screen actually renders.
    static func make(_ tempos: [Int?]) -> TempoTrendDisplay {
      let summary = ItemPracticeSummary.fixture(
        tempoTrend: .fixture(tempos.map { $0.map { UInt16($0) } }))
      guard
        let display = summary.tempoTrendDisplay(
          locale: Locale(identifier: "en_US"), calendar: PreviewCalendar.utc)
      else { preconditionFailure("preview tempos must include a measurement") }
      return display
    }
  }

  extension TempoTrendView {
    /// `tempos[i]` is the i-th session's tempo, `nil` where none was measured.
    /// Dates run three days apart and end on 2026-06-24, matching the
    /// `scoreHistory` fixtures beside it, so a summary's `lastPracticedAt` and
    /// its trend agree however many tempos are passed.
    static func fixture(_ tempos: [UInt16?]) -> TempoTrendView {
      let newest = Date(timeIntervalSince1970: 1_782_291_600)
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime]
      let points = tempos.enumerated().map { index, tempo in
        let daysBack = Double(tempos.count - 1 - index) * 3 * 86_400
        return TempoTrendPoint(
          sessionDate: formatter.string(from: newest.addingTimeInterval(-daysBack)),
          sessionId: "t\(index)",
          tempo: tempo)
      }
      return TempoTrendView(points: points, hasTrend: tempos.compactMap { $0 }.count >= 2)
    }
  }

  extension ItemPracticeSummary {
    /// Preview and snapshot fixture. A new core field costs one edit here rather
    /// than one per call site (CLAUDE.md, Testing).
    static func fixture(
      sessionCount: UInt64 = 0,
      totalMinutes: UInt32 = 0,
      latestScore: UInt8? = nil,
      scoreHistory: [ScoreHistoryEntry] = [],
      latestTempo: UInt16? = nil,
      tempoTrend: TempoTrendView = TempoTrendView(points: [], hasTrend: false),
      lastPracticedAt: String? = nil
    ) -> ItemPracticeSummary {
      ItemPracticeSummary(
        sessionCount: sessionCount, totalMinutes: totalMinutes, latestScore: latestScore,
        scoreHistory: scoreHistory, latestTempo: latestTempo, tempoTrend: tempoTrend,
        lastPracticedAt: lastPracticedAt)
    }
  }

  /// A fixed Gregorian/UTC calendar so date-derived UI (the week strip) renders
  /// identically on any host — pair it with `previewReferenceDate` in previews
  /// and pin it via `.environment(\.calendar, PreviewCalendar.utc)` in snapshot hosts.
  enum PreviewCalendar {
    static var utc: Calendar {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
      return calendar
    }
  }

  /// Offline bridge for Xcode previews: serves the core's initial (empty)
  /// ViewModel — optionally seeded with library items — and emits no effects,
  /// so store-backed screens render in the canvas without FFI networking.
  final class PreviewBridge: CoreBridge {
    private let core = CoreFfi()
    private let items: [LibraryItemView]
    private let activeQuery: ListQuery?
    private let sessions: [PracticeSessionView]
    private let buildingSetlist: BuildingSetlistView?
    private let activeSession: ActiveSessionView?
    private let summary: SummaryView?

    private let analytics: AnalyticsView?
    private let lastPractised: LastPractisedView?
    private let upNext: SuggestedSession?
    private let recentlyPractised: [LibraryItemView]
    private let profile: ProfileView?

    init(
      items: [LibraryItemView] = [], activeQuery: ListQuery? = nil,
      sessions: [PracticeSessionView] = [], buildingSetlist: BuildingSetlistView? = nil,
      activeSession: ActiveSessionView? = nil, summary: SummaryView? = nil,
      analytics: AnalyticsView? = nil, lastPractised: LastPractisedView? = nil,
      upNext: SuggestedSession? = nil, recentlyPractised: [LibraryItemView] = [],
      profile: ProfileView? = nil
    ) {
      self.items = items
      self.activeQuery = activeQuery
      self.sessions = sessions
      self.buildingSetlist = buildingSetlist
      self.activeSession = activeSession
      self.summary = summary
      self.analytics = analytics
      self.lastPractised = lastPractised
      self.upNext = upNext
      self.recentlyPractised = recentlyPractised
      self.profile = profile
    }

    func update(_ event: Event) throws -> [Request] { [] }
    func resolve(_ id: UInt32, persistenceOutput: PersistenceOutput) throws -> [Request] { [] }
    func resolve(_ id: UInt32, recognitionOutput: RecognitionOutput) throws -> [Request] { [] }
    func resolveEmpty(_ id: UInt32) throws -> [Request] { [] }
    func view() throws -> ViewModel {
      var viewModel = try ViewModel.bincodeDeserialize(input: [UInt8](core.view()))
      viewModel.activeQuery = activeQuery
      let visible: [LibraryItemView]
      if let kind = activeQuery?.itemType {
        visible = items.filter { $0.itemType == kind }
      } else {
        visible = items
      }
      viewModel.items = visible
      // The unfiltered set the pickers read, as the core projects it (#1484).
      viewModel.allItems = items
      // Type-filters items; callers pre-filter the list for text/tag queries.
      viewModel.visiblePieces = UInt64(visible.filter { $0.itemType == .piece }.count)
      viewModel.visibleExercises = UInt64(visible.filter { $0.itemType == .exercise }.count)
      // Derived from the whole library, never `visible`, so a fixture with a
      // filter on still reports what the core would report (#981).
      viewModel.hasPriorities = items.contains { $0.priority }
      viewModel.sessions = sessions
      viewModel.buildingSetlist = buildingSetlist
      viewModel.activeSession = activeSession
      viewModel.summary = summary
      if let analytics { viewModel.analytics = analytics }
      viewModel.lastPractised = lastPractised
      viewModel.upNext = upNext
      viewModel.recentlyPractised = recentlyPractised
      if let profile { viewModel.profile = profile }
      return viewModel
    }
  }

  extension Store {
    /// A deterministic, offline store for `#Preview` blocks.
    static var preview: Store { Store(bridge: PreviewBridge()) }

    /// A cellist called Jon on coral, greeted in the morning (#1692).
    static var previewProfile: Store {
      Store(bridge: PreviewBridge(profile: .previewCellist))
    }

    /// An offline store with curated sample items (specific edge cases).
    /// Used by snapshot tests where the exact data must be deterministic.
    static var previewLibrary: Store {
      Store(bridge: PreviewBridge(items: [.previewPiece, .previewExercise, .previewMinimal]))
    }

    /// Pieces-filtered library for the filtered-state snapshot (#792).
    static var previewLibraryFiltered: Store {
      Store(
        bridge: PreviewBridge(
          items: [.previewPiece, .previewExercise, .previewMinimal],
          activeQuery: ListQuery(text: nil, itemType: .piece, key: nil, tags: [])))
    }

    /// Text-searched library for the revealed-search-bar snapshot: "clair"
    /// matches Clair de Lune. The bridge serves the already-matched subset.
    static var previewLibrarySearching: Store {
      Store(
        bridge: PreviewBridge(
          items: [.previewPiece],
          activeQuery: ListQuery(text: "clair", itemType: nil, key: nil, tags: [])))
    }

    /// A store driven by the *real* core seeded with the canonical demo dataset
    /// (`Event.loadSampleData` → `sample_items()`). Render-only, so it completes
    /// synchronously and offline. Use in screen previews: same data as the CI
    /// screenshot, and the filter pills actually work in the canvas.
    /// Not for snapshot tests — `sample_items()` stamps wall-clock timestamps.
    static var previewSeeded: Store {
      let store = Store()
      store.send(.loadSampleData)
      return store
    }

    /// Library with a populated Priorities section (2 starred, 1 not) for the
    /// pinned-section snapshot. Injected directly so priority + ids are stable.
    static var previewLibraryPriorities: Store {
      Store(
        bridge: PreviewBridge(items: [
          starred(.previewPiece), starred(.previewExercise), .previewMinimal,
        ]))
    }

    private static func starred(_ item: LibraryItemView) -> LibraryItemView {
      var copy = item
      copy.priority = true
      return copy
    }

    /// Practice home with deterministic sessions (fixed past dates) for the
    /// populated-state snapshot — covers both completed + ended-early cards.
    static var previewPractice: Store {
      Store(
        bridge: PreviewBridge(
          sessions: [.previewCompleted, .previewEndedEarly],
          lastPractised: .previewYesterday))
    }

    /// The Practice home as a named cellist sees it: greeted, with the badge (#1694).
    static var previewPracticeProfile: Store {
      Store(
        bridge: PreviewBridge(
          sessions: [.previewCompleted, .previewEndedEarly],
          lastPractised: .previewYesterday, profile: .previewCellist))
    }

    /// Practice home with something to suggest (#1082).
    static var previewPracticeSuggestion: Store {
      Store(
        bridge: PreviewBridge(
          sessions: [.previewCompleted, .previewEndedEarly],
          lastPractised: .previewYesterday, upNext: .previewStarred))
    }

    /// Practice home with something starred, so the priorities route shows
    /// under the ordinary hero (#981).
    static var previewPracticePriorities: Store {
      Store(
        bridge: PreviewBridge(
          items: [starred(.previewPiece), .previewMinimal],
          sessions: [.previewCompleted, .previewEndedEarly],
          lastPractised: .previewYesterday))
    }

    /// A suggestion and a starred library together: the one layout where two
    /// secondary actions stack under a single primary (#981).
    static var previewPracticeSuggestionPriorities: Store {
      Store(
        bridge: PreviewBridge(
          items: [starred(.previewPiece), .previewMinimal],
          sessions: [.previewCompleted, .previewEndedEarly],
          lastPractised: .previewYesterday, upNext: .previewStarred))
    }

    /// Practice home with a crash-recovery blob pending (#962) — drives the
    /// Resume / Discard prompt above the hero.
    static var previewPracticeRecovery: Store {
      let store = Store(
        bridge: PreviewBridge(
          sessions: [.previewCompleted, .previewEndedEarly],
          lastPractised: .previewYesterday))
      store.recoverableSession = ActiveSession(
        id: "recover-1",
        entries: [
          SetlistEntry(
            id: "re1", itemId: "i1", itemTitle: "Scales · D♭ major", itemType: .exercise,
            position: 0, durationSecs: 180, status: .completed,
            notes: nil, intention: nil, plannedDurationSecs: nil,
            groupId: nil, plannedVariationId: nil, plannedRepTarget: nil,
            plays: [
              VariationPlay(
                id: "re1-p1", variationId: nil, startedAt: "2026-06-16T08:59:00Z",
                seconds: 180, repTarget: nil, repCount: nil, repTargetReached: nil,
                repHistory: nil, achievedTempo: nil, clickPattern: nil, score: nil)
            ]),
          SetlistEntry(
            id: "re2", itemId: "i2", itemTitle: "Clair de Lune", itemType: .piece,
            position: 1, durationSecs: 0, status: .notAttempted,
            notes: nil, intention: nil, plannedDurationSecs: nil,
            groupId: nil, plannedVariationId: nil, plannedRepTarget: nil, plays: []),
        ],
        currentIndex: 1,
        currentItemStartedAt: "2026-06-16T09:02:00Z", sessionStartedAt: "2026-06-16T09:02:00Z",
        sessionIntention: nil)
      return store
    }

    /// Session builder mid-assembly: a non-empty setlist for the populated-state
    /// preview + snapshot. Injected directly (deterministic, offline) rather than
    /// driven through the core, whose ulids/timestamps aren't snapshot-stable.
    static var previewBuilding: Store {
      Store(
        bridge: PreviewBridge(
          items: [.previewPiece, .previewExercise, .previewMinimal],
          buildingSetlist: BuildingSetlistView(
            entries: [.previewPiece, .previewExercise],
            itemCount: 2,
            blocks: [
              SetlistBlockView(
                groupId: nil, pieceTitle: nil, relatedCount: 0, durationDisplay: "—",
                entries: [.previewPiece]),
              SetlistBlockView(
                groupId: nil, pieceTitle: nil, relatedCount: 0, durationDisplay: "—",
                entries: [.previewExercise]),
            ],
            blockCount: 2,
            totalDurationDisplay: nil, totalDurationSummary: nil,
            sessionIntention: nil, targetDurationMins: nil)))
    }

    /// Session builder's add-items sheet with a "Recently practised" quick-add
    /// section (#1362), independent of `previewBuilding`'s own items/setlist.
    static var previewBuildingRecentlyPractised: Store {
      Store(
        bridge: PreviewBridge(
          items: [.previewPiece, .previewExercise, .previewMinimal],
          buildingSetlist: BuildingSetlistView(
            entries: [], itemCount: 0, blocks: [], blockCount: 0,
            totalDurationDisplay: nil, totalDurationSummary: nil,
            sessionIntention: nil, targetDurationMins: nil),
          recentlyPractised: [.previewPiece, .previewExercise]))
    }

    /// Same as `previewBuildingRecentlyPractised`, but with the type filter set
    /// to exercises — the section must not survive an active filter (#1362).
    static var previewBuildingRecentlyPractisedFiltered: Store {
      Store(
        bridge: PreviewBridge(
          items: [.previewExercise],
          activeQuery: ListQuery(text: nil, itemType: .exercise, key: nil, tags: []),
          buildingSetlist: BuildingSetlistView(
            entries: [], itemCount: 0, blocks: [], blockCount: 0,
            totalDurationDisplay: nil, totalDurationSummary: nil,
            sessionIntention: nil, targetDurationMins: nil),
          recentlyPractised: [.previewPiece, .previewExercise]))
    }

    /// Session builder with a block (a piece + 2 related) above a standalone
    /// item — the grouped-state preview + snapshot.
    static var previewBuildingGrouped: Store {
      let block: [SetlistEntryView] = [
        .previewGroupedScales, .previewGroupedArpeggios, .previewGroupedPiece,
      ]
      return Store(
        bridge: PreviewBridge(
          items: [.previewPiece, .previewExercise, .previewMinimal],
          buildingSetlist: BuildingSetlistView(
            entries: block + [.previewStandaloneExercise],
            itemCount: 4,
            blocks: [
              SetlistBlockView(
                groupId: "g1", pieceTitle: "Clair de Lune", relatedCount: 2,
                durationDisplay: "12 min", entries: block),
              SetlistBlockView(
                groupId: nil, pieceTitle: nil, relatedCount: 0, durationDisplay: "—",
                entries: [.previewStandaloneExercise]),
            ],
            blockCount: 2,
            totalDurationDisplay: "12m 0s", totalDurationSummary: "12 min",
            sessionIntention: nil, targetDurationMins: nil)))
    }

    /// Session builder where one of the block's related exercises is also in
    /// the library — the added state of the add-related sheet (#1103).
    static var previewBuildingGroupedAdded: Store {
      let block: [SetlistEntryView] = [.previewGroupedScales, .previewGroupedPiece]
      return Store(
        bridge: PreviewBridge(
          items: [.previewScales, .previewExercise],
          buildingSetlist: BuildingSetlistView(
            entries: block,
            itemCount: 2,
            blocks: [
              SetlistBlockView(
                groupId: "g1", pieceTitle: "Clair de Lune", relatedCount: 1,
                durationDisplay: "12 min", entries: block)
            ],
            blockCount: 1,
            totalDurationDisplay: "12m 0s", totalDurationSummary: "12 min",
            sessionIntention: nil, targetDurationMins: nil)))
    }

    /// Player Focus — a piece mid-session with a session intention and a time
    /// target (the target bar), no reps.
    static var previewActive: Store {
      Store(bridge: PreviewBridge(activeSession: .previewActive))
    }

    /// Player Focus — an exercise with an active rep counter.
    static var previewActiveLongSession: Store {
      Store(bridge: PreviewBridge(activeSession: .previewActiveLongSession))
    }

    static var previewActiveReps: Store {
      Store(bridge: PreviewBridge(activeSession: .previewActiveReps))
    }

    /// Player Focus: an exercise with variations, so the picker chip shows
    /// what is being practised right now (#1739).
    static var previewActiveVariations: Store {
      Store(
        bridge: PreviewBridge(
          items: [.previewExerciseWithVariations], activeSession: .previewActiveVariations))
    }

    static var previewSummary: Store {
      Store(bridge: PreviewBridge(summary: .previewSummary, analytics: .previewAnalytics))
    }

    /// Player Summary: one exercise practised across three keys, so each gets
    /// its own mark (#1739 decision 10).
    static var previewSummaryVariations: Store {
      Store(bridge: PreviewBridge(summary: .previewSummaryVariations))
    }

    /// Player Summary — intention echo + all three reflection prompts filled.
    static var previewSummaryWithReflection: Store {
      Store(bridge: PreviewBridge(summary: .previewSummaryWithReflection))
    }

    /// Player Summary — ended early, so the unreached item shows not-attempted.
    static var previewSummaryEndedEarly: Store {
      Store(bridge: PreviewBridge(summary: .previewSummaryEndedEarly))
    }

    /// Progress: a populated analytics view (dial, consistency, recent
    /// mastery) plus two practised exercises with variations, so the coverage
    /// section renders (#1739).
    static var previewProgress: Store {
      Store(
        bridge: PreviewBridge(
          items: [
            scored(.previewExerciseWithVariations, 7),
            scored(.previewExerciseWithTwelveVariations, 6),
          ],
          analytics: .previewAnalytics))
    }

    /// Library where rows carry a mastery score, so the trailing meters fill.
    static var previewLibraryMastery: Store {
      Store(
        bridge: PreviewBridge(items: [
          scored(.previewPiece, 4), scored(.previewExercise, 3), .previewMinimal,
        ]))
    }

    /// Detail view: piece with 3 linked exercises (varied scores, one unrated).
    static var previewDetailLinkedPopulated: Store {
      Store(bridge: PreviewBridge(items: [.previewDetailWithLinkedExercises]))
    }

    /// Detail view: piece with no linked exercises — shows the empty state.
    static var previewDetailLinkedEmpty: Store {
      Store(bridge: PreviewBridge(items: [.previewDetailLinkedEmpty]))
    }

    /// Detail view: exercise linked to 2 pieces it has never been practised with.
    static var previewExerciseLinkedOnlyStore: Store {
      Store(bridge: PreviewBridge(items: [.previewExerciseLinkedOnly]))
    }

    private static func scored(_ item: LibraryItemView, _ score: UInt8) -> LibraryItemView {
      var copy = item
      copy.practice = ItemPracticeSummary.fixture(
        sessionCount: 8, totalMinutes: 120, latestScore: score, scoreHistory: [],
        latestTempo: nil, lastPracticedAt: "2026-05-30T09:00:00Z")
      return copy
    }
  }

  extension AnalyticsView {
    /// A deterministic analytics fixture for the Progress screen + snapshots.
    /// `scoreTrends` (all items' latest score) drives the dial mean (≈3.4);
    /// `scoreChanges` (this week's movers) drive the Recent-mastery rows; weekly
    /// `dailyTotals` roll up to the consistency bars (40/75/55/95/82).
    static var previewAnalytics: AnalyticsView {
      AnalyticsView(
        weeklySummary: WeeklySummary(
          totalMinutes: 380, sessionCount: 14, itemsCovered: 11,
          prevTotalMinutes: 300, prevSessionCount: 11, prevItemsCovered: 9,
          timeDirection: .up, sessionsDirection: .up, itemsDirection: .up,
          hasPrevWeekData: true),
        streak: PracticeStreak(currentDays: 4),
        dailyTotals: [
          DailyPracticeTotal(date: "2026-04-29", minutes: 40),
          DailyPracticeTotal(date: "2026-05-06", minutes: 75),
          DailyPracticeTotal(date: "2026-05-13", minutes: 55),
          DailyPracticeTotal(date: "2026-05-20", minutes: 95),
          DailyPracticeTotal(date: "2026-05-28", minutes: 82),
        ],
        topItems: [
          ItemRanking(
            itemId: "piece-1", itemTitle: "Clair de Lune", itemType: .piece,
            totalMinutes: 180, sessionCount: 9)
        ],
        scoreTrends: [
          scoreTrend("piece-1", "Clair de Lune", 4),
          scoreTrend("exercise-1", "Hanon No. 1", 4),
          scoreTrend("piece-2", "Gymnopédie No. 1", 3),
          scoreTrend("piece-3", "Nocturne Op. 9", 3),
          scoreTrend("exercise-2", "Major Scales", 3),
        ],
        neglectedItems: [],
        scoreChanges: [
          ScoreChange(
            itemId: "piece-1", itemTitle: "Clair de Lune", previousScore: 3,
            currentScore: 4, delta: 1, isNew: false),
          ScoreChange(
            itemId: "exercise-1", itemTitle: "Hanon No. 1", previousScore: 2,
            currentScore: 3, delta: 1, isNew: false),
          ScoreChange(
            itemId: "piece-2", itemTitle: "Gymnopédie No. 1", previousScore: nil,
            currentScore: 3, delta: 0, isNew: true),
        ],
        variationCoverage: [
          VariationCoverageView(itemId: "exercise-2", title: "Major Scales", solid: 7, total: 12),
          VariationCoverageView(itemId: "exercise-1", title: "Hanon No. 1", solid: 1, total: 3),
        ])
    }

    private static func scoreTrend(_ id: String, _ title: String, _ latest: UInt8)
      -> ItemScoreTrend
    {
      ItemScoreTrend(
        itemId: id, itemTitle: title,
        scores: [ScorePoint(date: "2026-05-30", score: latest)], latestScore: latest)
    }
  }

  extension LibraryItemView {
    static var previewPiece: LibraryItemView {
      LibraryItemView(
        id: "piece-1", itemType: .piece, title: "Clair de Lune", subtitle: "Claude Debussy",
        key: "Db", modality: .major, tempo: "Andante (72 BPM)", tempoMarking: "Andante",
        tempoBpm: 72,
        notes: nil, tags: [], createdAt: "", updatedAt: "", practice: nil,
        latestAchievedTempo: nil, priority: false,
        linkedExercises: [
          LinkedExerciseView(
            id: "exercise-1", title: "Hanon No. 1", key: "C major", tempo: "♩ = 108",
            practice: nil, pieceContextScore: 7),
          LinkedExerciseView(
            id: "exercise-2", title: "Db Major Scale", key: "Db major", tempo: nil, practice: nil,
            pieceContextScore: nil),
        ],
        usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil,
        variants: [], ladderIsKeys: false, photoId: nil)
    }

    static var previewExercise: LibraryItemView {
      LibraryItemView(
        id: "exercise-1", itemType: .exercise, title: "Hanon No. 1",
        subtitle: "Charles-Louis Hanon",
        key: "C", modality: .major, tempo: "108 BPM", tempoMarking: nil, tempoBpm: 108,
        notes: nil, tags: [], createdAt: "", updatedAt: "", practice: nil,
        latestAchievedTempo: nil, priority: false, linkedExercises: [],
        usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil, variants: [],
        ladderIsKeys: false,
        photoId: nil)
    }

    /// The library item behind `previewGroupedScales`, so a block member and a
    /// library row can share an id.
    static var previewScales: LibraryItemView {
      LibraryItemView(
        id: "ex-a", itemType: .exercise, title: "Scales", subtitle: "",
        key: nil, modality: nil, tempo: nil, tempoMarking: nil, tempoBpm: nil,
        notes: nil, tags: [], createdAt: "", updatedAt: "", practice: nil,
        latestAchievedTempo: nil, priority: false, linkedExercises: [],
        usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil, variants: [],
        ladderIsKeys: false,
        photoId: nil)
    }

    static var previewDetail: LibraryItemView {
      LibraryItemView(
        id: "piece-3", itemType: .piece, title: "Clair de Lune", subtitle: "Claude Debussy",
        key: "Db", modality: .major, tempo: "Andante (72 BPM)", tempoMarking: "Andante",
        tempoBpm: 72,
        notes: "Focus on the rubato in the opening phrase; keep the left hand soft.",
        tags: ["recital", "impressionist", "memorised"], createdAt: "", updatedAt: "",
        practice: nil, latestAchievedTempo: nil, priority: false, linkedExercises: [],
        usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil,
        variants: [], ladderIsKeys: false, photoId: nil)
    }

    /// A charted piece — exercises the chord-chart card (parsed grid + preview).
    static var previewCharted: LibraryItemView {
      func chord(_ raw: String, _ root: UInt8, _ q: ChordQuality) -> ChartChord {
        ChartChord(
          symbol: ChordSymbol(root: root, quality: q, extensions: [], bass: nil, raw: raw),
          beats: 4)
      }
      let chart = ChordChart(
        key: "G", modality: .minor,
        sections: [
          ChartSection(
            label: "A",
            bars: [
              Bar(chords: [chord("Cm7", 0, .min7)]),
              Bar(chords: [chord("F7", 5, .dom7)]),
              Bar(chords: [chord("Bbmaj7", 10, .maj7)]),
              Bar(chords: [chord("Ebmaj7", 3, .maj7)]),
            ])
        ])
      return LibraryItemView(
        id: "piece-charted", itemType: .piece, title: "Autumn Leaves", subtitle: "Standard",
        key: "G", modality: .minor, tempo: nil, tempoMarking: nil, tempoBpm: nil,
        notes: nil, tags: [], createdAt: "", updatedAt: "", practice: nil,
        latestAchievedTempo: nil, priority: false, linkedExercises: [],
        usedIn: [], scaffoldPreview: .preview, chordChart: chart, metre: nil, variants: [],
        ladderIsKeys: false,
        photoId: nil)
    }

    static var previewMinimal: LibraryItemView {
      LibraryItemView(
        id: "piece-2", itemType: .piece, title: "Prelude in C", subtitle: "",
        key: nil, modality: nil, tempo: nil, tempoMarking: nil, tempoBpm: nil,
        notes: nil, tags: [], createdAt: "", updatedAt: "", practice: nil,
        latestAchievedTempo: nil, priority: false, linkedExercises: [],
        usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil, variants: [],
        ladderIsKeys: false,
        photoId: nil)
    }

    /// A piece with a populated linked-exercises list (3 items, varied scores including
    /// one unrated) — for the linked-exercises section snapshots.
    static var previewDetailWithLinkedExercises: LibraryItemView {
      LibraryItemView(
        id: "piece-3", itemType: .piece, title: "Clair de Lune", subtitle: "Claude Debussy",
        key: "Db", modality: .major, tempo: "Andante (72 BPM)", tempoMarking: "Andante",
        tempoBpm: 72,
        notes: "Focus on the rubato in the opening phrase; keep the left hand soft.",
        tags: ["recital", "impressionist"], createdAt: "", updatedAt: "",
        practice: ItemPracticeSummary.fixture(
          sessionCount: 12, totalMinutes: 240, latestScore: 6,
          scoreHistory: [
            ScoreHistoryEntry(sessionDate: "2026-06-24T09:00:00Z", score: 6, sessionId: "s1"),
            ScoreHistoryEntry(sessionDate: "2026-06-21T09:00:00Z", score: 5, sessionId: "s2"),
            ScoreHistoryEntry(sessionDate: "2026-06-18T09:00:00Z", score: 4, sessionId: "s3"),
          ],
          latestTempo: 72, tempoTrend: .fixture([66, nil, 69, 72]),
          lastPracticedAt: "2026-06-24T09:00:00Z"),
        latestAchievedTempo: nil, priority: false,
        linkedExercises: [
          // Per-piece scores deliberately differ from the exercises' overall
          // `latestScore` (7 / 4), so the snapshot shows the B2 re-source.
          LinkedExerciseView(
            id: "exercise-1", title: "Hanon No. 1", key: "C major", tempo: "♩ = 108",
            practice: ItemPracticeSummary.fixture(
              sessionCount: 8, totalMinutes: 60, latestScore: 7, scoreHistory: [],
              latestTempo: 108, tempoTrend: .fixture([100, 104, 108]),
              lastPracticedAt: "2026-06-28T09:00:00Z"),
            pieceContextScore: 5),
          LinkedExerciseView(
            id: "exercise-2", title: "Db Major Scale", key: "Db major", tempo: nil,
            practice: ItemPracticeSummary.fixture(
              sessionCount: 3, totalMinutes: 20, latestScore: 4, scoreHistory: [],
              latestTempo: nil, lastPracticedAt: "2026-06-25T09:00:00Z"),
            pieceContextScore: 6),
          LinkedExerciseView(
            id: "exercise-3", title: "Arpeggios in Db", key: nil, tempo: nil,
            practice: nil, pieceContextScore: nil),
        ],
        usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil,
        variants: [], ladderIsKeys: false, photoId: nil)
    }

    /// Linked to 2 pieces, neither practised yet: every row unrated (#1363).
    static var previewExerciseLinkedOnly: LibraryItemView {
      LibraryItemView(
        id: "exercise-1", itemType: .exercise, title: "Hanon No. 1",
        subtitle: "Charles-Louis Hanon",
        key: "C", modality: .major, tempo: "108 BPM", tempoMarking: nil, tempoBpm: 108,
        notes: nil, tags: [], createdAt: "", updatedAt: "",
        practice: ItemPracticeSummary.fixture(
          sessionCount: 9, totalMinutes: 90, latestScore: 7,
          scoreHistory: [
            ScoreHistoryEntry(sessionDate: "2026-06-24T09:00:00Z", score: 7, sessionId: "e1"),
            ScoreHistoryEntry(sessionDate: "2026-06-21T09:00:00Z", score: 6, sessionId: "e2"),
            ScoreHistoryEntry(sessionDate: "2026-06-18T09:00:00Z", score: 5, sessionId: "e3"),
          ],
          latestTempo: 108, tempoTrend: .fixture([96, 100, nil, 104, 108]),
          lastPracticedAt: "2026-06-24T09:00:00Z"),
        latestAchievedTempo: nil, priority: false, linkedExercises: [],
        usedIn: [
          ExerciseUsageView(
            piece: PieceRefView(id: "piece-1", title: "Clair de Lune", subtitle: "Claude Debussy"),
            linked: true, latestScore: nil, sessionCount: 0, lastPracticedAt: nil,
            pieceRemoved: false),
          ExerciseUsageView(
            piece: PieceRefView(id: "piece-2", title: "Gymnopédie No. 1", subtitle: "Erik Satie"),
            linked: true, latestScore: nil, sessionCount: 0, lastPracticedAt: nil,
            pieceRemoved: false),
        ], scaffoldPreview: nil, chordChart: nil, metre: nil, variants: [], ladderIsKeys: false,
        photoId: nil)
    }

    /// Every "Used in" row state at once: linked and practised, practised
    /// only, linked only, removed, and "On its own" (#1087 B2, #1363).
    static var previewExerciseUsedIn: LibraryItemView {
      LibraryItemView(
        id: "exercise-1", itemType: .exercise, title: "Enclosures",
        subtitle: "Bebop vocabulary",
        key: "C", modality: .major, tempo: "120 BPM", tempoMarking: nil, tempoBpm: 120,
        notes: nil, tags: [], createdAt: "", updatedAt: "",
        practice: ItemPracticeSummary.fixture(
          sessionCount: 10, totalMinutes: 120, latestScore: 7,
          scoreHistory: [
            ScoreHistoryEntry(sessionDate: "2026-06-24T09:00:00Z", score: 7, sessionId: "e1")
          ],
          latestTempo: 120, tempoTrend: .fixture([120]),
          lastPracticedAt: "2026-06-24T09:00:00Z"),
        latestAchievedTempo: nil, priority: false, linkedExercises: [],
        usedIn: [
          ExerciseUsageView(
            piece: PieceRefView(
              id: "piece-1", title: "Strasbourg / St. Denis", subtitle: "Woody Shaw"),
            linked: true, latestScore: 7, sessionCount: 3,
            lastPracticedAt: "2026-06-24T09:00:00Z", pieceRemoved: false),
          ExerciseUsageView(
            piece: PieceRefView(id: "piece-2", title: "Blue Bossa", subtitle: "Kenny Dorham"),
            linked: false, latestScore: 5, sessionCount: 2,
            lastPracticedAt: "2026-06-22T09:00:00Z", pieceRemoved: false),
          ExerciseUsageView(
            piece: PieceRefView(id: "piece-3", title: "Autumn Leaves", subtitle: "Kosma"),
            linked: true, latestScore: nil, sessionCount: 0, lastPracticedAt: nil,
            pieceRemoved: false),
          ExerciseUsageView(
            piece: PieceRefView(id: "piece-gone", title: "Solar", subtitle: nil),
            linked: false, latestScore: 4, sessionCount: 2,
            lastPracticedAt: "2026-06-20T09:00:00Z", pieceRemoved: true),
          ExerciseUsageView(
            piece: nil, linked: false, latestScore: 6, sessionCount: 4,
            lastPracticedAt: "2026-06-21T09:00:00Z", pieceRemoved: false),
        ], scaffoldPreview: nil, chordChart: nil, metre: nil, variants: [], ladderIsKeys: false,
        photoId: nil)
    }

    /// An exercise with variations: one solid, one marked but not yet solid,
    /// one unrated.
    static var previewExerciseWithVariations: LibraryItemView {
      LibraryItemView(
        id: "exercise-2", itemType: .exercise, title: "ii–V–i Enclosures",
        subtitle: "Bebop vocabulary, 12 keys",
        key: "C", modality: .major, tempo: "132 BPM", tempoMarking: nil, tempoBpm: 132,
        notes: nil, tags: [], createdAt: "", updatedAt: "",
        practice: nil, latestAchievedTempo: nil, priority: false, linkedExercises: [],
        usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil,
        variants: [
          VariantView(
            id: "variation-c", label: "C", position: 0, latestScore: 9, scoreHistory: [],
            isSolid: true),
          VariantView(
            id: "variation-f", label: "F", position: 1, latestScore: 5, scoreHistory: [],
            isSolid: false),
          VariantView(
            id: "variation-bb", label: "B♭", position: 2, latestScore: nil, scoreHistory: [],
            isSolid: false),
        ], ladderIsKeys: true, photoId: nil)
    }

    /// Twelve chromatic variations, stress-testing the horizontal scroller
    /// at max realistic length (#1083 C2).
    static var previewExerciseWithTwelveVariations: LibraryItemView {
      let keys = [
        "C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B",
      ]
      return LibraryItemView(
        id: "exercise-3", itemType: .exercise, title: "Chromatic run",
        subtitle: "All 12 keys",
        key: nil, modality: nil, tempo: "72 BPM", tempoMarking: nil, tempoBpm: 72,
        notes: nil, tags: [], createdAt: "", updatedAt: "",
        practice: nil, latestAchievedTempo: nil, priority: false, linkedExercises: [],
        usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil,
        variants: keys.enumerated().map { index, label in
          let solid = index < 4
          let current = index == 4
          return VariantView(
            id: "variation-\(index)", label: label, position: UInt64(index),
            latestScore: solid ? 9 : (current ? 6 : nil), scoreHistory: [],
            isSolid: solid)
        }, ladderIsKeys: true, photoId: nil)
    }

    /// Variations that are inversions, not keys: pins the "variations" word and the stairs
    /// glyph, the one judgement the shell still makes for itself (#1467).
    static var previewExerciseWithNamedVariations: LibraryItemView {
      let rungs = ["Root position", "1st inversion", "2nd inversion"]
      return LibraryItemView(
        id: "exercise-4", itemType: .exercise, title: "Triad inversions", subtitle: "",
        key: nil, modality: nil, tempo: nil, tempoMarking: nil, tempoBpm: nil,
        notes: nil, tags: [], createdAt: "", updatedAt: "",
        practice: nil, latestAchievedTempo: nil, priority: false, linkedExercises: [],
        usedIn: [], scaffoldPreview: nil, chordChart: nil, metre: nil,
        variants: rungs.enumerated().map { index, label in
          VariantView(
            id: "rung-\(index)", label: label, position: UInt64(index), latestScore: nil,
            scoreHistory: [], isSolid: false)
        }, ladderIsKeys: false, photoId: nil)
    }

    /// A piece with no linked exercises — for the empty-state snapshot.
    static var previewDetailLinkedEmpty: LibraryItemView {
      LibraryItemView(
        id: "piece-4", itemType: .piece, title: "Gymnopédie No. 1", subtitle: "Erik Satie",
        key: "D", modality: .major, tempo: "Lent et douloureux (60 BPM)",
        tempoMarking: "Lent et douloureux",
        tempoBpm: 60, notes: nil, tags: [], createdAt: "", updatedAt: "",
        practice: nil, latestAchievedTempo: nil, priority: false,
        linkedExercises: [], usedIn: [], scaffoldPreview: nil,
        chordChart: nil, metre: nil, variants: [], ladderIsKeys: false, photoId: nil)
    }
  }

  extension SetlistEntryView {
    static var previewPiece: SetlistEntryView {
      building(id: "setlist-1", item: "piece-1", title: "Clair de Lune", type: .piece, position: 0)
    }

    static var previewExercise: SetlistEntryView {
      building(
        id: "setlist-2", item: "exercise-1", title: "Hanon No. 1", type: .exercise, position: 1)
    }

    static var previewGroupedScales: SetlistEntryView {
      building(id: "g-a", item: "ex-a", title: "Scales", type: .exercise, position: 0, group: "g1")
    }
    static var previewGroupedArpeggios: SetlistEntryView {
      building(
        id: "g-b", item: "ex-b", title: "Broken arpeggios", type: .exercise, position: 1,
        group: "g1")
    }
    static var previewGroupedPiece: SetlistEntryView {
      building(
        id: "g-p", item: "piece-1", title: "Clair de Lune", type: .piece, position: 2, group: "g1")
    }
    static var previewStandaloneExercise: SetlistEntryView {
      building(id: "g-s", item: "ex-c", title: "Sight-reading", type: .exercise, position: 3)
    }

    /// All three per-entry settings set — the "populated" `EntrySettingsSheet` snapshot.
    static var previewGroupedScalesConfigured: SetlistEntryView {
      var e = previewGroupedScales
      e.intention = "Even RH over the LH arpeggios"
      e.plannedRepTarget = 7
      e.plannedDurationSecs = 360
      e.plannedDurationDisplay = "6 min"
      return e
    }

    private static func building(
      id: String, item: String, title: String, type: ItemKind, position: UInt64,
      group: String? = nil
    ) -> SetlistEntryView {
      SetlistEntryView(
        id: id, itemId: item, itemTitle: title, itemType: type, position: position,
        // Escaped rather than the glyph: check-dashes.sh reads changed lines,
        // and an em dash is what the builder row has always shown here.
        durationDisplay: "\u{2014}", status: .notAttempted, notes: nil, intention: nil,
        plannedDurationSecs: nil, plannedDurationDisplay: nil, groupId: group,
        plannedVariationId: nil, plannedRepTarget: nil, plays: [], scoreSummary: nil)
    }
  }

  extension LastPractisedView {
    /// What the core projects for `previewCompleted` (Sat 30 May, headline
    /// Clair de Lune) read on `previewReferenceDate`, the Sunday after.
    static var previewYesterday: LastPractisedView {
      LastPractisedView(
        itemTitle: "Clair de Lune", relativeDay: "Yesterday",
        label: "Last practised yesterday")
    }
  }

  // Reason strings below are copies of the core's, per the table in
  // specs/up-next-card.md decision 6 — reword there and these go stale silently.
  extension SuggestedSession {
    /// The mock's case: starred and cold, one drill unmarked, one on a variation.
    static var previewStarred: SuggestedSession {
      SuggestedSession(
        pieceId: "piece-1", pieceTitle: "Like Someone in Love",
        pieceSubtitle: "Jimmy Van Heusen",
        reason: "A priority · cold for 5 weeks", priority: true,
        items: [
          SuggestedItem(
            itemId: "ex-1", itemTitle: "Guide tones", itemType: .exercise,
            variantId: nil, variantLabel: nil, latestScore: nil,
            reason: "Not marked with this piece"),
          SuggestedItem(
            itemId: "ex-2", itemTitle: "Shell voicings", itemType: .exercise,
            variantId: "variation-f", variantLabel: "F", latestScore: 4,
            reason: "Marked 4 of 10 last time"),
          SuggestedItem(
            itemId: "piece-1", itemTitle: "Like Someone in Love", itemType: .piece,
            variantId: nil, variantLabel: nil, latestScore: 6,
            reason: "Marked 6 of 10 last time"),
        ],
        estimatedMinutes: 15)
    }

    /// Unstarred and untouched — the longest copy the card has to fit.
    static var previewFresh: SuggestedSession {
      SuggestedSession(
        pieceId: "piece-2", pieceTitle: "Prelude in C", pieceSubtitle: nil,
        reason: "Not practised yet", priority: false,
        items: [
          SuggestedItem(
            itemId: "ex-3", itemTitle: "Contrary-motion scales", itemType: .exercise,
            variantId: nil, variantLabel: nil, latestScore: nil,
            reason: "Not marked with this piece"),
          SuggestedItem(
            itemId: "piece-2", itemTitle: "Prelude in C", itemType: .piece,
            variantId: nil, variantLabel: nil, latestScore: nil,
            reason: "Not marked yet"),
        ],
        estimatedMinutes: 10)
    }
  }

  extension PracticeSessionView {
    /// Sunday 31 May 2026 (noon UTC) — same Mon–Sun week as the fixtures below
    /// (Thu 28th, Sat 30th). "Today" has no practice, so the screen auto-selects
    /// the most recent earlier practice day (Sat 30th), exercising both the
    /// today-ring and selected-fill states deterministically.
    static var previewReferenceDate: Date {
      var components = DateComponents()
      components.year = 2026
      components.month = 5
      components.day = 31
      components.hour = 12
      return PreviewCalendar.utc.date(from: components) ?? .distantPast
    }

    /// Fixed past dates (not "now") so the card renders a deterministic absolute
    /// date — reusable from snapshot tests as well as the canvas.
    static var previewCompleted: PracticeSessionView {
      PracticeSessionView(
        id: "session-1", startedAt: "2026-05-30T09:00:00Z", finishedAt: "2026-05-30T09:32:00Z",
        totalDurationDisplay: "32m 0s", totalDurationSummary: "32m",
        completionStatus: .completed,
        notes: "Left hand steadier once I slowed the middle section right down.",
        entries: [
          previewEntry(0, "Clair de Lune", .piece, score: 7, tempo: 66),
          previewEntry(
            1, "Gymnopédie No. 1", .piece, score: 8,
            notes: "Pedal changes cleaner than last week."),
          previewEntry(
            2, "Nocturne Op. 9 No. 2", .piece, score: 6, tempo: 54, repTarget: 5, repCount: 5),
        ],
        sessionIntention: "Keep the pulse steady without the click",
        sessionScore: 7,
        reflectionImproved: nil, reflectionStillRough: nil, reflectionNextTarget: nil)
    }

    /// One exercise practised across three keys, so the detail screen lists a
    /// line per variation rather than only the last (#1739).
    static var previewWithVariations: PracticeSessionView {
      PracticeSessionView(
        id: "session-3", startedAt: "2026-05-29T10:00:00Z", finishedAt: "2026-05-29T10:20:00Z",
        totalDurationDisplay: "20m 30s", totalDurationSummary: "20m",
        completionStatus: .completed, notes: nil,
        entries: [SetlistEntryView.previewThreeVariations],
        sessionIntention: "One key at a time, no rushing", sessionScore: 8,
        reflectionImproved: nil, reflectionStillRough: nil, reflectionNextTarget: nil)
    }

    /// No session mark, and the two statuses a detail view must state plainly
    /// rather than leave looking unmarked.
    static var previewEndedEarly: PracticeSessionView {
      PracticeSessionView(
        id: "session-2", startedAt: "2026-05-28T18:00:00Z", finishedAt: "2026-05-28T18:14:00Z",
        totalDurationDisplay: "14m 0s", totalDurationSummary: "14m",
        completionStatus: .endedEarly, notes: nil,
        entries: [
          previewEntry(0, "Hanon No. 1", .exercise, score: 5, repTarget: 10, repCount: 4),
          previewEntry(1, "Major Scales", .exercise, status: .notAttempted),
        ],
        sessionIntention: nil, sessionScore: nil,
        reflectionImproved: nil, reflectionStillRough: nil, reflectionNextTarget: nil)
    }

    private static func previewEntry(
      _ position: UInt64, _ title: String, _ type: ItemKind,
      status: EntryStatus = .completed, score: UInt8? = nil, tempo: UInt16? = nil,
      repTarget: UInt8? = nil, repCount: UInt8? = nil, notes: String? = nil
    ) -> SetlistEntryView {
      let plays =
        status == .completed
        ? [
          VariationPlayView(
            id: "entry-\(position)-p1", variationId: nil, variationLabel: nil, seconds: 600,
            durationDisplay: "10 min", repTarget: repTarget, repCount: repCount,
            repTargetReached: repTarget.map { repCount ?? 0 >= $0 }, repHistory: nil,
            achievedTempo: tempo, clickPattern: nil, score: score)
        ] : []
      return SetlistEntryView(
        id: "entry-\(position)", itemId: "item-\(position)", itemTitle: title, itemType: type,
        position: position, durationDisplay: "10 min", status: status, notes: notes,
        intention: nil, plannedDurationSecs: nil, plannedDurationDisplay: nil, groupId: nil,
        plannedVariationId: nil, plannedRepTarget: nil, plays: plays,
        scoreSummary: plays.isEmpty ? nil : score)
    }
  }

  extension ActiveSessionView {
    /// Item start instant + the snapshot reference (start + 4:12) so the timer
    /// renders a fixed `04:12` deterministically.
    static let previewStartedAt = "2026-05-30T09:00:00Z"
    /// Deliberately before the item started, so the session timer and the item
    /// ring cannot both be right by reading the same field.
    static let previewSessionStartedAt = "2026-05-30T08:47:00Z"
    /// Past an hour, where `clockDisplay` switches to `H:MM:SS` and the reading
    /// outgrows the orientation slot. An hour at the piano is ordinary, not an
    /// edge case.
    static let previewLongSessionStartedAt = "2026-05-30T07:52:00Z"
    static var previewReferenceDate: Date {
      (SessionClock.parseRFC3339(previewStartedAt) ?? .distantPast).addingTimeInterval(252)
    }

    private static func previewEntry(
      _ position: UInt64, _ title: String, _ type: ItemKind, groupId: String? = nil
    )
      -> SetlistEntryView
    {
      SetlistEntryView(
        id: "entry-\(position)", itemId: "item-\(position)", itemTitle: title, itemType: type,
        position: position, durationDisplay: "10 min", status: .completed, notes: nil,
        intention: nil, plannedDurationSecs: nil, plannedDurationDisplay: nil,
        groupId: groupId, plannedVariationId: nil, plannedRepTarget: nil,
        plays: [
          VariationPlayView(
            id: "entry-\(position)-p1", variationId: nil, variationLabel: nil, seconds: 600,
            durationDisplay: "10 min", repTarget: nil, repCount: nil, repTargetReached: nil,
            repHistory: nil, achievedTempo: nil, clickPattern: nil, score: nil)
        ], scoreSummary: nil)
    }

    static var previewActive: ActiveSessionView {
      ActiveSessionView(
        currentItemTitle: "Clair de Lune", currentItemType: .piece,
        currentPosition: 1, totalItems: 5,
        startedAt: previewSessionStartedAt, currentItemStartedAt: previewStartedAt,
        entries: [
          previewEntry(0, "Hanon No. 1", .exercise),
          previewEntry(1, "Clair de Lune", .piece),
          previewEntry(2, "Major Scales", .exercise),
          previewEntry(3, "Gymnopédie No. 1", .piece),
          previewEntry(4, "Czerny Op. 299", .exercise),
        ], sessionIntention: "Even tempo — don't rush the runs",
        currentRepTarget: nil, currentRepCount: nil, currentRepTargetReached: nil,
        currentRepHistory: nil, currentRepSlots: 10,
        currentVariationId: nil, currentVariationLabel: nil,
        currentPlannedDurationSecs: 480,
        nextItemTitle: "Hanon No. 1",
        currentItemIntention: "Let the melody breathe", currentRelatedPieceTitle: nil,
        currentItemTempoMarking: "Andante", currentItemTempoBpm: 66, currentItemMetre: nil)
    }

    /// The same session, run past an hour, so the `H:MM:SS` reading is drawn.
    static var previewActiveLongSession: ActiveSessionView {
      let base = previewActive
      return ActiveSessionView(
        currentItemTitle: base.currentItemTitle, currentItemType: base.currentItemType,
        currentPosition: base.currentPosition, totalItems: base.totalItems,
        startedAt: previewLongSessionStartedAt, currentItemStartedAt: base.currentItemStartedAt,
        entries: base.entries, sessionIntention: base.sessionIntention,
        currentRepTarget: base.currentRepTarget, currentRepCount: base.currentRepCount,
        currentRepTargetReached: base.currentRepTargetReached,
        currentRepHistory: base.currentRepHistory, currentRepSlots: 10,
        currentVariationId: base.currentVariationId,
        currentVariationLabel: base.currentVariationLabel,
        currentPlannedDurationSecs: base.currentPlannedDurationSecs,
        nextItemTitle: base.nextItemTitle, currentItemIntention: base.currentItemIntention,
        currentRelatedPieceTitle: base.currentRelatedPieceTitle,
        currentItemTempoMarking: base.currentItemTempoMarking,
        currentItemTempoBpm: base.currentItemTempoBpm, currentItemMetre: nil)
    }

    /// The current item is an exercise practised in C, now on G: the chip reads
    /// the open play and the picker switches it (#1739).
    static var previewActiveVariations: ActiveSessionView {
      ActiveSessionView(
        currentItemTitle: LibraryItemView.previewExerciseWithVariations.title,
        currentItemType: .exercise,
        currentPosition: 0, totalItems: 3,
        startedAt: previewSessionStartedAt, currentItemStartedAt: previewStartedAt,
        entries: [
          variationEntry(), previewEntry(1, "Clair de Lune", .piece),
          previewEntry(2, "Czerny Op. 299", .exercise),
        ], sessionIntention: "One key at a time, no rushing",
        currentRepTarget: 10, currentRepCount: 4, currentRepTargetReached: false,
        currentRepHistory: nil, currentRepSlots: 10,
        currentVariationId: "variation-f", currentVariationLabel: "F",
        currentPlannedDurationSecs: 480,
        nextItemTitle: "Clair de Lune",
        currentItemIntention: "Even tone through the turn",
        currentRelatedPieceTitle: nil,
        currentItemTempoMarking: nil, currentItemTempoBpm: 104, currentItemMetre: nil)
    }

    /// The current entry of `previewActiveVariations`: one closed play in C and
    /// an open one in F, whose seconds the core has not stamped yet.
    private static func variationEntry() -> SetlistEntryView {
      SetlistEntryView(
        id: "entry-0", itemId: "exercise-2",
        itemTitle: LibraryItemView.previewExerciseWithVariations.title,
        itemType: .exercise, position: 0, durationDisplay: "10 min", status: .notAttempted,
        notes: nil, intention: nil, plannedDurationSecs: nil, plannedDurationDisplay: nil,
        groupId: nil, plannedVariationId: "variation-c", plannedRepTarget: 10,
        plays: [
          VariationPlayView(
            id: "entry-0-p1", variationId: "variation-c", variationLabel: "C", seconds: 190,
            durationDisplay: "3m 10s", repTarget: 10, repCount: 10, repTargetReached: true,
            repHistory: nil, achievedTempo: nil, clickPattern: nil, score: nil),
          VariationPlayView(
            id: "entry-0-p2", variationId: "variation-f", variationLabel: "F", seconds: 0,
            durationDisplay: "0s", repTarget: 10, repCount: 4, repTargetReached: false,
            repHistory: nil, achievedTempo: nil, clickPattern: nil, score: nil),
        ], scoreSummary: nil)
    }

    static var previewActiveReps: ActiveSessionView {
      ActiveSessionView(
        currentItemTitle: "Hanon No. 1", currentItemType: .exercise,
        currentPosition: 2, totalItems: 5,
        startedAt: previewSessionStartedAt, currentItemStartedAt: previewStartedAt,
        entries: [
          previewEntry(0, "Warm-up Scales", .exercise),
          previewEntry(1, "Etude No. 3", .exercise),
          previewEntry(2, "Hanon No. 1", .exercise, groupId: "g1"),
          previewEntry(3, "Moonlight Sonata", .piece, groupId: "g1"),
          previewEntry(4, "Czerny Op. 299", .exercise),
        ], sessionIntention: "Keep the wrist relaxed",
        currentRepTarget: 10, currentRepCount: 7, currentRepTargetReached: false,
        currentRepHistory: nil, currentRepSlots: 10,
        currentVariationId: nil, currentVariationLabel: nil,
        currentPlannedDurationSecs: nil,
        nextItemTitle: "Czerny Op. 299",
        currentItemIntention: "Land each finger evenly",
        currentRelatedPieceTitle: "Moonlight Sonata",
        currentItemTempoMarking: "Allegro", currentItemTempoBpm: 132, currentItemMetre: nil)
    }
  }

  extension SummaryView {
    /// One exercise across three keys beside a piece with a single play, so
    /// the screen shows both shapes at once (#1739).
    static var previewSummaryVariations: SummaryView {
      SummaryView(
        totalDurationDisplay: "20m 30s", completionStatus: .completed, notes: nil,
        entries: [
          SetlistEntryView.previewThreeVariations,
          summaryEntry("e2", "Clair de Lune", .piece, "7m 50s", 470, .completed, score: 6),
        ],
        sessionIntention: "One key at a time, no rushing", sessionScore: nil,
        reflectionImproved: nil, reflectionStillRough: nil, reflectionNextTarget: nil)
    }

    static var previewSummary: SummaryView {
      SummaryView(
        totalDurationDisplay: "37m 50s", completionStatus: .completed, notes: nil,
        entries: [
          summaryEntry("e1", "Clair de Lune", .piece, "12m 40s", 760, .completed, score: 3),
          summaryEntry(
            "e2", "Hanon No. 1", .exercise, "8m 10s", 490, .completed, score: 4, tempo: 96,
            intention: "Land each finger evenly"),
          summaryEntry(
            "e3", "Gymnopédie No. 1", .piece, "11m 30s", 690, .completed, score: 5,
            notes: "Pedal changes cleaner than last week."),
          summaryEntry("e4", "Czerny Op. 299", .exercise, "5m 30s", 330, .completed, score: 3),
        ], sessionIntention: nil, sessionScore: 8,
        reflectionImproved: nil, reflectionStillRough: nil, reflectionNextTarget: nil)
    }

    /// Intention echo + all three reflection prompts filled — locks the
    /// surface-3 reflection block (design/briefs/2026-07-reflection-and-narrative.md).
    static var previewSummaryWithReflection: SummaryView {
      SummaryView(
        totalDurationDisplay: "37m 50s", completionStatus: .completed, notes: nil,
        entries: [
          summaryEntry("e1", "Clair de Lune", .piece, "12m 40s", 760, .completed, score: 3),
          summaryEntry(
            "e2", "Hanon No. 1", .exercise, "8m 10s", 490, .completed, score: 4, tempo: 96,
            intention: "Land each finger evenly"),
        ], sessionIntention: "Even RH through bars 12–14", sessionScore: 8,
        reflectionImproved: "Thumb-unders even at 92 — bars 1–8 clean twice in a row.",
        reflectionStillRough: "Bars 12–14 rush every run past 88.",
        reflectionNextTarget: "Bars 12–14 at 80, hands together, before pushing tempo.")
    }

    static var previewSummaryEndedEarly: SummaryView {
      SummaryView(
        totalDurationDisplay: "20m 50s", completionStatus: .endedEarly, notes: nil,
        entries: [
          summaryEntry("e1", "Clair de Lune", .piece, "12m 40s", 760, .completed, score: 3),
          summaryEntry("e2", "Hanon No. 1", .exercise, "8m 10s", 490, .completed, score: 4),
          summaryEntry("e3", "Étude Op. 10", .piece, "0s", 0, .notAttempted, score: nil),
        ], sessionIntention: nil, sessionScore: 8,
        reflectionImproved: nil, reflectionStillRough: nil, reflectionNextTarget: nil)
    }

    private static func summaryEntry(
      _ id: String, _ title: String, _ type: ItemKind, _ duration: String, _ seconds: UInt64,
      _ status: EntryStatus, score: UInt8?, tempo: UInt16? = nil, intention: String? = nil,
      notes: String? = nil
    ) -> SetlistEntryView {
      let plays =
        status == .completed
        ? [
          VariationPlayView(
            id: "\(id)-p1", variationId: nil, variationLabel: nil, seconds: seconds,
            durationDisplay: duration, repTarget: nil, repCount: nil, repTargetReached: nil,
            repHistory: nil, achievedTempo: tempo, clickPattern: nil, score: score)
        ] : []
      return SetlistEntryView(
        id: id, itemId: id, itemTitle: title, itemType: type, position: 0,
        durationDisplay: duration, status: status, notes: notes, intention: intention,
        plannedDurationSecs: nil, plannedDurationDisplay: nil, groupId: nil,
        plannedVariationId: nil, plannedRepTarget: nil, plays: plays,
        scoreSummary: plays.isEmpty ? nil : score)
    }
  }

  extension ReflectionPlay {
    static func preview(
      _ id: String, _ label: String?, _ duration: String, _ repCount: UInt8? = nil,
      _ repTarget: UInt8? = nil
    ) -> ReflectionPlay {
      ReflectionPlay(
        id: id, variationLabel: label, durationDisplay: duration, repCount: repCount,
        repTarget: repTarget)
    }
  }

  extension VariationPlayView {
    /// Three variations of one item, as the item-complete sheet and the session
    /// detail read them (#1739).
    static func preview(
      _ id: String, _ variationLabel: String?, seconds: UInt64, duration: String,
      score: UInt8? = nil, tempo: UInt16? = nil, repCount: UInt8? = nil,
      repTarget: UInt8? = nil
    ) -> VariationPlayView {
      VariationPlayView(
        id: id, variationId: variationLabel.map { "v-\($0)" }, variationLabel: variationLabel,
        seconds: seconds, durationDisplay: duration, repTarget: repTarget, repCount: repCount,
        repTargetReached: repTarget.map { (repCount ?? 0) >= $0 }, repHistory: nil,
        achievedTempo: tempo, clickPattern: nil, score: score)
    }
  }

  extension SetlistEntryView {
    /// One exercise practised across three keys: the case #1739 exists for.
    static var previewThreeVariations: SetlistEntryView {
      let plays = [
        VariationPlayView.preview(
          "p1", "C major", seconds: 250, duration: "4m 10s", score: 7, repCount: 8, repTarget: 10),
        VariationPlayView.preview(
          "p2", "G major", seconds: 200, duration: "3m 20s", score: 9, tempo: 104, repCount: 10,
          repTarget: 10),
        VariationPlayView.preview(
          "p3", "D major", seconds: 310, duration: "5m 10s", repCount: 4, repTarget: 10),
      ]
      return SetlistEntryView(
        id: "entry-variations", itemId: "exercise-2", itemTitle: "Major Scales",
        itemType: .exercise, position: 0, durationDisplay: "12m 40s", status: .completed,
        notes: nil, intention: "Even tone through the turn", plannedDurationSecs: nil,
        plannedDurationDisplay: nil, groupId: nil, plannedVariationId: "v-C major",
        plannedRepTarget: 10, plays: plays, scoreSummary: 8)
    }
  }
#endif

#if DEBUG
  extension PhotoDraft {
    /// A clean title and tempo, and a composer the OCR was not sure of (#1436).
    static var readPage: PhotoDraft {
      PhotoDraft(
        title: TextDraftField(
          value: "Autumn Leaves", source: .recognised, confidence: 0.93, weak: false),
        composer: TextDraftField(
          value: "Joseph Kosmo", source: .recognised, confidence: 0.34, weak: true),
        tempo: TempoDraftField(
          value: Tempo(marking: "Moderato", bpm: 120), source: .recognised, confidence: 0.9,
          weak: false),
        chartText: nil)
    }

    static var otherReadPage: PhotoDraft {
      PhotoDraft(
        title: TextDraftField(
          value: "Blues in F", source: .recognised, confidence: 0.9, weak: false),
        composer: TextDraftField(
          value: "Count Basie", source: .recognised, confidence: 0.88, weak: false),
        tempo: nil,
        chartText: nil)
    }

    static var readNothing: PhotoDraft {
      PhotoDraft(title: nil, composer: nil, tempo: nil, chartText: nil)
    }
  }
  extension ProfileView {
    static var previewCellist: ProfileView {
      ProfileView(
        name: "Jon", instrument: "Cello", suggestedIcon: .cello, icon: .cello, colour: .coral,
        greeting: "Morning, Jon")
    }
  }
#endif
