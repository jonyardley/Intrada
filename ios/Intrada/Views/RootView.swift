import SharedTypes
import SwiftUI

struct RootView: View {
  @Environment(Store.self) private var store
  @Environment(\.scenePhase) private var scenePhase

  private enum AppTab {
    case library, practice, routines, progress
  }

  @State private var selectedTab: AppTab = .library
  /// One per app: `isIdleTimerDisabled` is process-global, so two would race.
  @State private var wakeLock = ScreenWakeLock.system()

  private let apiBaseURL = "https://intrada-api.fly.dev"

  init() {
    Self.applyTabBarAppearance()
    Self.applyNavBarAppearance()
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      LibrarySplitView().screenTransaction("Library")
        .tabItem { Label("Library", systemImage: "books.vertical") }
        .tag(AppTab.library)
      NavigationStack {
        PracticeScreen().screenTransaction("Practice")
      }
      .tabItem { Label("Practice", systemImage: "timer") }
      .tag(AppTab.practice)
      RoutinesScreen().screenTransaction("Routines")
        .tabItem { Label("Routines", systemImage: "music.note.list") }
        .tag(AppTab.routines)
      AnalyticsScreen().screenTransaction("Progress")
        .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        .tag(AppTab.progress)
    }
    .tint(IntradaColor.accent)
    // State-driven: building can now start outside the Practice tab (the
    // exercise detail's "Practise this"), and the builder only presents from
    // PracticeScreen's navigationDestination — so follow the core there.
    .onChange(of: store.viewModel?.buildingSetlist != nil) { _, isBuilding in
      if isBuilding { selectedTab = .practice }
    }
    // The session player takes over the whole screen (no tab bar) while the core
    // is Active or Summary — "the app disappears during practice". State-driven:
    // the core drives presentation and dismissal (Save/Discard → Idle), so there's
    // no interactive dismiss to honour.
    .fullScreenCover(isPresented: playerBinding) {
      PlayerHost().environment(store).environment(\.screenWakeLock, wakeLock)
    }
    // App-level surfaces below the status bar, above all tabs. Empty when there's
    // nothing to show, so it adds no inset (keeps the plain shell unchanged).
    .safeAreaInset(edge: .top, spacing: 0) {
      VStack(spacing: 0) {
        if store.degraded {
          GlobalBanner(message: "Storage unavailable · changes this session won't be saved.")
        }
        if let error = store.viewModel?.error {
          GlobalBanner(message: error) { store.send(.clearError) }
        }
      }
    }
    .task {
      store.reportUtcOffset()
      // Default (incl. plain DEBUG runs): local-first — the Library hydrates
      // from the on-device store so saved items survive restarts. Seeding is
      // opt-in via --seed-sample-data (ios-run-sim.sh / CI screenshots / E2E);
      // it loads demo data and skips StartApp so a late fetch can't clobber it.
      if seedSampleData {
        store.send(.loadSampleData)
      } else {
        store.send(.startApp(apiBaseUrl: apiBaseURL, localFirst: true))
        store.restorePersistedSort()
        store.loadRecoverableSession()
      }
    }
    // Re-report on foreground: the offset moves under a resident app on DST
    // turnover or travel, and analytics' day boundary must move with it.
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { store.reportUtcOffset() }
    }
  }

  private var playerBinding: Binding<Bool> {
    Binding(
      get: { store.viewModel?.activeSession != nil || store.viewModel?.summary != nil },
      set: { _ in })  // no interactive dismiss — the core owns the session phase
  }

  private var seedSampleData: Bool { UITestFlags.seedSampleData }

  private static func applyTabBarAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = UIColor(IntradaColor.tabBarFill)

    // iOS 26's glass tab bar styles itself and ignores these item colours; they
    // apply on iOS 25 and earlier (active tint also comes from `.tint`).
    let normal = appearance.stackedLayoutAppearance.normal
    normal.iconColor = UIColor(IntradaColor.inkSecondary)
    normal.titleTextAttributes = [.foregroundColor: UIColor(IntradaColor.inkSecondary)]

    let selected = appearance.stackedLayoutAppearance.selected
    selected.iconColor = UIColor(IntradaColor.accent)
    selected.titleTextAttributes = [.foregroundColor: UIColor(IntradaColor.accent)]

    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
  }

  private static func applyNavBarAppearance() {
    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    let ink = UIColor(IntradaColor.ink)
    if let large = UIFont(name: IntradaFont.Hanken.semibold, size: 28) {
      appearance.largeTitleTextAttributes = [.font: large, .foregroundColor: ink]
    }
    if let inline = UIFont(name: IntradaFont.Hanken.semibold, size: 16) {
      appearance.titleTextAttributes = [.font: inline, .foregroundColor: ink]
    }
    UINavigationBar.appearance().standardAppearance = appearance
    UINavigationBar.appearance().scrollEdgeAppearance = appearance
    UINavigationBar.appearance().compactAppearance = appearance
  }
}

#if DEBUG
  #Preview {
    RootView()
      .environment(Store.previewSeeded)
  }
#endif
