//
//  SessionComponents.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SharedTypes
import SwiftUI

// MARK: - Session Row Components

struct SessionRowWithActions: View {
    let session: PracticeSession
    let viewModel: SessionViewModel
    let core: Core
    let onSessionEnd: (PracticeSession) -> Void
    let onTap: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                HStack {
                    // Tappable content area
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text(session.intention)
                            .font(Theme.Typography.headline)

                        if let notes = session.notes, !notes.isEmpty {
                            Text(notes)
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }

                        HStack {
                            if let startTime = extractStartTime(from: session.state) {
                                HStack(spacing: Theme.Spacing.extraSmall) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(Theme.Colors.primary)
                                    Text(DateFormatter.formatDate(startTime))
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }

                            Spacer()

                            SessionStateView(state: session.state)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap()
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: Theme.Spacing.small) {
                        if case .started = session.state {
                            Button("End") {
                                onSessionEnd(session)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: PracticeSession
    let viewModel: SessionViewModel

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text(session.intention)
                    .font(Theme.Typography.headline)

                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                HStack {
                    if let startTime = extractStartTime(from: session.state) {
                        HStack(spacing: Theme.Spacing.extraSmall) {
                            Image(systemName: "calendar")
                                .foregroundColor(Theme.Colors.primary)
                            Text(DateFormatter.formatDate(startTime))
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    SessionStateView(state: session.state)
                }
            }
        }
    }
}

// MARK: - Session State View

private struct SessionStateView: View {
    let state: SessionState

    var body: some View {
        HStack(spacing: Theme.Spacing.extraSmall) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            Text(stateText)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }

    private var stateColor: Color {
        switch state {
        case .notStarted:
            return Color.gray
        case .started:
            return Color.green
        case .pendingReflection:
            return Color.orange
        case .ended:
            return Color.blue
        }
    }

    private var stateText: String {
        switch state {
        case .notStarted:
            return "Not Started"
        case .started:
            return "In Progress"
        case .pendingReflection:
            return "Pending Reflection"
        case .ended:
            return "Completed"
        }
    }
}

// MARK: - Helper Functions

private func extractStartTime(from state: SessionState) -> String? {
    switch state {
    case let .started(startTime), let .pendingReflection(startTime, _), let .ended(startTime, _, _):
        return startTime
    case .notStarted:
        return nil
    }
}

extension DateFormatter {
    static func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}
