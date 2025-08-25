//
//  SessionRow.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SharedTypes
import SwiftUI

// MARK: - Session Row Components

struct SessionRow: View {
    let session: PracticeSession
    let viewModel: SessionViewModel

    var body: some View {
        GenericRow {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                    Text(session.intention)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.text)

                    Text(sessionTimeDescription())
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                Spacer()

                SessionStateBadge(state: session.state)
            }
        }
        .padding(.horizontal, Theme.Spacing.large)
    }

    private func sessionTimeDescription() -> String {
        switch session.state {
        case let .ended(startTime, endTime, _):
            let formatter = ISO8601DateFormatter()
            guard let start = formatter.date(from: startTime),
                  let end = formatter.date(from: endTime)
            else {
                return "Completed"
            }
            let duration = end.timeIntervalSince(start)
            let minutes = Int(duration / 60)
            return "Completed • \(minutes) min"

        case let .started(startTime):
            if let start = ISO8601DateFormatter().date(from: startTime) {
                let duration = Date().timeIntervalSince(start)
                let minutes = Int(duration / 60)
                return "Started \(minutes) min ago"
            }
            return "In Progress"

        case .pendingReflection:
            return "Pending Reflection"

        case .notStarted:
            return "Not Started"
        }
    }
}

struct SessionRowWithActions: View {
    let session: PracticeSession
    let viewModel: SessionViewModel
    let core: Core
    let onSessionEnd: (PracticeSession) -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GenericRow {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                        Text(session.intention)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.text)

                        HStack(spacing: Theme.Spacing.small) {
                            Text(sessionTimeDescription())
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)

                            if case .started = session.state {
                                DynamicTimerView(
                                    session: session,
                                    fontSize: .caption,
                                    textColor: Theme.Colors.primary
                                )
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: Theme.Spacing.small) {
                        SessionStateBadge(state: session.state)

                        if case .pendingReflection = session.state {
                            Button("Reflect") {
                                onSessionEnd(session)
                            }
                            .font(Theme.Typography.caption)
                            .padding(.horizontal, Theme.Spacing.small)
                            .padding(.vertical, Theme.Spacing.extraSmall)
                            .background(Theme.Colors.primary)
                            .foregroundColor(.white)
                            .cornerRadius(Theme.CornerRadius.small)
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, Theme.Spacing.large)
    }

    private func sessionTimeDescription() -> String {
        switch session.state {
        case let .started(startTime):
            if let start = ISO8601DateFormatter().date(from: startTime) {
                let duration = Date().timeIntervalSince(start)
                let minutes = Int(duration / 60)
                return "Started \(minutes) min ago"
            }
            return "In Progress"

        case .pendingReflection:
            return "Needs Reflection"

        case .notStarted:
            return "Ready to Start"

        case let .ended(_, _, durationInSeconds):
            let minutes = Int(durationInSeconds / 60)
            return "Completed • \(minutes) min"
        }
    }
}
