import SharedTypes
import SwiftUI

// MARK: - Helper Functions

private func stateDisplayName(_ state: SessionState) -> String {
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

// MARK: - Session Detail Components

struct SessionHeaderView: View {
    let session: PracticeSession

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                        Text("Session")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)

                        Text(session.intention)
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.text)
                    }

                    Spacer()

                    SessionStateBadge(state: session.state)
                }

                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(3)
                        .padding(.top, Theme.Spacing.small)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.large)
    }
}

struct SessionSummaryView: View {
    let session: PracticeSession

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Text("Summary")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.text)

                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    SummaryRow(label: "Status", value: stateDisplayName(session.state))
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.large)
    }
}

struct SessionNotesView: View {
    let session: PracticeSession

    var body: some View {
        if let notes = session.notes, !notes.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                    Text("Notes")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.text)

                    Text(notes)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.large)
        }
    }
}

struct SessionTimesView: View {
    let session: PracticeSession

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                Text("Timeline")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.text)

                VStack(alignment: .leading, spacing: Theme.Spacing.small) {

                    if case let .started(startTime) = session.state {
                        if let startDate = ISO8601DateFormatter().date(from: startTime) {
                            TimelineRow(
                                icon: "play.circle",
                                label: "Started",
                                time: startDate,
                                color: Theme.Colors.success
                            )
                        }
                    }

                    if case let .pendingReflection(startTime, endTime) = session.state {
                        if let startDate = ISO8601DateFormatter().date(from: startTime) {
                            TimelineRow(
                                icon: "play.circle",
                                label: "Started",
                                time: startDate,
                                color: Theme.Colors.success
                            )
                        }
                        if let endDate = ISO8601DateFormatter().date(from: endTime) {
                            TimelineRow(
                                icon: "pause.circle",
                                label: "Ended",
                                time: endDate,
                                color: Theme.Colors.warning
                            )
                        }
                    }

                    if case let .ended(startTime, endTime, _) = session.state {
                        if let startDate = ISO8601DateFormatter().date(from: startTime) {
                            TimelineRow(
                                icon: "play.circle",
                                label: "Started",
                                time: startDate,
                                color: Theme.Colors.success
                            )
                        }
                        if let endDate = ISO8601DateFormatter().date(from: endTime) {
                            TimelineRow(
                                icon: "checkmark.circle",
                                label: "Completed",
                                time: endDate,
                                color: Theme.Colors.success
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.large)
    }
}

struct SessionRelatedGoalsView: View {
    let session: PracticeSession
    let core: Core

    var relatedGoals: [PracticeGoal] {
        session.goalIds.compactMap { goalId in
            core.view.goals.first { $0.id == goalId }
        }
    }

    var body: some View {
        if !relatedGoals.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                    Text("Related Goals")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.text)

                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        ForEach(relatedGoals, id: \.id) { goal in
                            NavigationLink(destination: GoalDetailView(core: core, goal: goal)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                                        Text(goal.name)
                                            .font(Theme.Typography.subheadline)
                                            .foregroundColor(Theme.Colors.text)

                                        if let description = goal.description, !description.isEmpty {
                                            Text(description)
                                                .font(Theme.Typography.caption)
                                                .foregroundColor(Theme.Colors.textSecondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.textTertiary)
                                }
                                .padding(.vertical, Theme.Spacing.extraSmall)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.large)
        }
    }
}

struct SessionStateTransitionButton: View {
    let session: PracticeSession
    let onStart: () -> Void
    let onEnd: () -> Void
    let onReflect: () -> Void

    var body: some View {
        switch session.state {
        case .notStarted:
            Button("Start") {
                onStart()
            }
            .foregroundColor(Theme.Colors.success)

        case .started:
            Button("End") {
                onEnd()
            }
            .foregroundColor(Theme.Colors.warning)

        case .pendingReflection:
            Button("Reflect") {
                onReflect()
            }
            .foregroundColor(Theme.Colors.primary)

        case .ended:
            EmptyView()
        }
    }
}

// MARK: - Helper Views

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)

            Spacer()

            Text(value)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.text)
        }
    }
}

struct TimelineRow: View {
    let icon: String
    let label: String
    let time: Date
    let color: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                Text(label)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.text)

                Text(time.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            Spacer()
        }
    }
}

struct SessionStateBadge: View {
    let state: SessionState

    var body: some View {
        Text(stateDisplayName(state))
            .font(Theme.Typography.caption)
            .padding(.horizontal, Theme.Spacing.small)
            .padding(.vertical, Theme.Spacing.extraSmall)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(Theme.CornerRadius.small)
    }

    private var backgroundColor: Color {
        switch state {
        case .notStarted:
            Theme.Colors.textTertiary.opacity(0.2)
        case .started:
            Theme.Colors.success.opacity(0.2)
        case .pendingReflection:
            Theme.Colors.warning.opacity(0.2)
        case .ended:
            Theme.Colors.primary.opacity(0.2)
        }
    }

    private var textColor: Color {
        switch state {
        case .notStarted:
            Theme.Colors.textSecondary
        case .started:
            Theme.Colors.success
        case .pendingReflection:
            Theme.Colors.warning
        case .ended:
            Theme.Colors.primary
        }
    }
}
