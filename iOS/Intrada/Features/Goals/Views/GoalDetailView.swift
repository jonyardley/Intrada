import SharedTypes
import SwiftUI

struct GoalDetailView: View {
    @ObservedObject var core: Core
    let goal: PracticeGoal
    @State private var showingEditForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                // Goal Header Card
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Text(goal.name)
                            .font(Theme.Typography.title)
                            .foregroundColor(Theme.Colors.text)

                        if let description = goal.description, !description.isEmpty {
                            Text(description)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.large)

                // Goal Details Card
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Text("Goal Details")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.text)

                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                            if let targetDate = goal.targetDate, !targetDate.isEmpty {
                                DetailRow(label: "Target Date", value: targetDate)
                            }

                            HStack {
                                Text("Status")
                                    .font(Theme.Typography.subheadline)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                Spacer()
                                StatusBadge(status: goal.status)
                            }

                            if let tempoTarget = goal.tempoTarget, tempoTarget > 0 {
                                DetailRow(label: "Target Tempo", value: "\(tempoTarget) BPM")
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.large)

                // Associated Studies Card
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Text("Studies")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.text)

                        let studies = core.view.studies.filter { study in
                            goal.studyIds.contains(study.id)
                        }

                        if studies.isEmpty {
                            Text("No studies associated")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(Theme.Spacing.large)
                        } else {
                            LazyVStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                ForEach(studies, id: \.id) { study in
                                    NavigationLink(destination: StudyDetailView(core: core, study: study)) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                                                Text(study.name)
                                                    .font(Theme.Typography.subheadline)
                                                    .foregroundColor(Theme.Colors.text)

                                                if let description = study.description, !description.isEmpty {
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
                }
                .padding(.horizontal, Theme.Spacing.large)
            }
            .padding(.vertical, Theme.Spacing.large)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditForm = true
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            GoalFormView(core: core, existingGoal: goal)
        }
    }
}

// MARK: - Helper Components

private struct DetailRow: View {
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

#Preview {
    GoalDetailView(
        core: Core(),
        goal: PracticeGoal(
            id: "1",
            name: "Sample Goal",
            description: "This is a sample goal",
            status: .inProgress,
            startDate: nil,
            targetDate: "2025-05-01",
            studyIds: [],
            tempoTarget: nil
        )
    )
}
