//
//  DashboardComponents.swift
//  Intrada
//
//  Created by Assistant on 30/05/2025.
//

import SharedTypes
import SwiftUI

// MARK: - Quick Actions View

struct QuickActionsView: View {
    @ObservedObject var core: Core
    let onQuickStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("Quick Actions")
                .font(Theme.Typography.title2)
                .padding(.horizontal, Theme.Spacing.large)

            HStack(spacing: Theme.Spacing.medium) {
                // Quick Start Session
                Button(action: onQuickStart) {
                    VStack(spacing: Theme.Spacing.small) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Colors.primary)

                        Text("Quick Start")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.large)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.CornerRadius.large)
                }
                .buttonStyle(PlainButtonStyle())

                // View Sessions
                NavigationLink(destination: SessionsView(core: core)) {
                    VStack(spacing: Theme.Spacing.small) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Colors.primary)

                        Text("Sessions")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.large)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.CornerRadius.large)
                }
                .buttonStyle(PlainButtonStyle())

                // View Goals
                NavigationLink(destination: GoalsView(core: core)) {
                    VStack(spacing: Theme.Spacing.small) {
                        Image(systemName: "target")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Colors.primary)

                        Text("Goals")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.large)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.CornerRadius.large)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, Theme.Spacing.large)
        }
    }
}

// MARK: - Stats Overview View

struct StatsOverviewView: View {
    let activeSessions: [PracticeSession]
    let completedSessions: [PracticeSession]
    let goalsCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("Your Progress")
                .font(Theme.Typography.title2)
                .padding(.horizontal, Theme.Spacing.large)

            HStack(spacing: Theme.Spacing.medium) {
                // Active Sessions Count
                StatCard(
                    title: "Active",
                    value: "\(activeSessions.count)",
                    subtitle: "sessions",
                    color: Theme.Colors.primary
                )

                // Completed Sessions Count
                StatCard(
                    title: "Completed",
                    value: "\(completedSessions.count)",
                    subtitle: "sessions",
                    color: Theme.Colors.success
                )

                // Goals Count
                StatCard(
                    title: "Goals",
                    value: "\(goalsCount)",
                    subtitle: "total",
                    color: Theme.Colors.secondary
                )
            }
            .padding(.horizontal, Theme.Spacing.large)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.extraSmall) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)

            Text(value)
                .font(Theme.Typography.title)
                .foregroundColor(color)

            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.medium)
        .background(Theme.Colors.background)
        .cornerRadius(Theme.CornerRadius.large)
    }
}

// MARK: - Current Session Card

struct CurrentSessionCard: View {
    let session: PracticeSession
    @ObservedObject var core: Core

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                        Text("Current Session")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)

                        Text(session.intention)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.text)
                    }

                    Spacer()

                    // Live timer
                    if case .started = session.state {
                        DynamicTimerView(
                            session: session,
                            fontSize: .title3,
                            textColor: Theme.Colors.primary
                        )
                    }
                }

                // Quick action to go to active session
                NavigationLink(destination: ActiveSessionDetailView(core: core, sessionId: session.id)) {
                    HStack {
                        Text("Continue Session")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.large)
    }
}

// MARK: - Recent Activity View

struct RecentActivityView: View {
    @ObservedObject var core: Core
    let recentSessions: [PracticeSession]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            HStack {
                Text("Recent Activity")
                    .font(Theme.Typography.title2)

                Spacer()

                NavigationLink("View All", destination: SessionsView(core: core))
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primary)
            }
            .padding(.horizontal, Theme.Spacing.large)

            if recentSessions.isEmpty {
                Text("No recent sessions")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.Spacing.large)
            } else {
                ForEach(recentSessions.prefix(3), id: \.id) { session in
                    NavigationLink(destination: SessionDetailView(core: core, sessionId: session.id)) {
                        RecentSessionRow(session: session)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

// MARK: - Recent Session Row

struct RecentSessionRow: View {
    let session: PracticeSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                Text(session.intention)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.text)

                if let duration = sessionDuration(session) {
                    Text(duration)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            sessionStateIndicator(session.state)
        }
        .padding(.horizontal, Theme.Spacing.large)
        .padding(.vertical, Theme.Spacing.small)
        .background(Theme.Colors.background)
        .cornerRadius(Theme.CornerRadius.medium)
        .padding(.horizontal, Theme.Spacing.large)
    }

    private func sessionStateIndicator(_ state: SessionState) -> some View {
        Group {
            switch state {
            case .notStarted:
                Image(systemName: "circle")
                    .foregroundColor(Theme.Colors.textSecondary)
            case .started:
                Image(systemName: "play.circle.fill")
                    .foregroundColor(Theme.Colors.primary)
            case .pendingReflection:
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(Theme.Colors.warning)
            case .ended:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.Colors.success)
            }
        }
    }

    private func sessionDuration(_ session: PracticeSession) -> String? {
        switch session.state {
        case let .ended(startTime, endTime, _):
            let formatter = ISO8601DateFormatter()
            guard let start = formatter.date(from: startTime),
                  let end = formatter.date(from: endTime)
            else {
                return nil
            }
            let duration = end.timeIntervalSince(start)
            let minutes = Int(duration / 60)
            return "\(minutes) min"
        default:
            return nil
        }
    }
}
