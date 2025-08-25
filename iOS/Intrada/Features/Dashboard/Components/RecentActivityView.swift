//
//  RecentActivityView.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SharedTypes
import SwiftUI

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
