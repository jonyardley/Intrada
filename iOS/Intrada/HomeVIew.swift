//
//  HomeVIew.swift
//  Intrada
//
//  Created by Jon Yardley on 30/05/2025.
//

import SharedTypes
import SwiftUI

struct HomeView: View {
    @ObservedObject var core: Core
    @State private var showingQuickStartForm = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                    // Welcome Header
                    welcomeHeaderView

                    // Current Session Card (if active)
                    if let currentSession = core.view.currentSession {
                        CurrentSessionCard(session: currentSession, core: core)
                    }

                    // Quick Actions
                    QuickActionsView(core: core, onQuickStart: { showingQuickStartForm = true })

                    // Stats Overview
                    StatsOverviewView(
                        activeSessions: core.view.sessions.filter { if case .started = $0.state { return true } else { return false } },
                        completedSessions: core.view.sessions.filter { if case .ended = $0.state { return true } else { return false } },
                        goalsCount: core.view.goals.count
                    )

                    // Recent Activity
                    RecentActivityView(core: core, recentSessions: recentSessions)

                    Spacer(minLength: Theme.Spacing.extraLarge)
                }
                .padding(.vertical, Theme.Spacing.large)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingQuickStartForm) {
            QuickStartSessionView(core: core, isPresented: $showingQuickStartForm)
        }
    }

    // MARK: - Computed Properties

    private var activeSessionsCount: Int {
        core.view.sessions.filter { session in
            if case .started = session.state { return true }
            return false
        }.count
    }

    private var completedSessionsCount: Int {
        core.view.sessions.filter { session in
            if case .ended = session.state { return true }
            return false
        }.count
    }

    private var recentSessions: [PracticeSession] {
        core.view.sessions
            .sorted { session1, session2 in
                switch (session1.state, session2.state) {
                case (.started, _):
                    true
                case (_, .started):
                    false
                case (.pendingReflection, .notStarted), (.pendingReflection, .ended):
                    true
                case (.notStarted, .pendingReflection), (.ended, .pendingReflection):
                    false
                default:
                    false
                }
            }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Views

    private var welcomeHeaderView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("Welcome back!")
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.text)

            Text("Ready to practice?")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.large)
    }
}
