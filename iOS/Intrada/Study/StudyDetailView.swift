import SharedTypes
import SwiftUI

struct StudyDetailView: View {
    @ObservedObject var core: Core
    let study: Study
    @State private var showingEditForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                // Study Header Card
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Text(study.name)
                            .font(Theme.Typography.title)
                            .foregroundColor(Theme.Colors.text)

                        if let description = study.description, !description.isEmpty {
                            Text(description)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.large)

                // Related Goals Card
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Text("Related Goals")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.text)

                    let goals = core.view.goals.filter { goal in
                        goal.studyIds.contains(study.id)
                    }

                        if goals.isEmpty {
                            Text("No goals associated")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(Theme.Spacing.large)
                        } else {
                            LazyVStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                ForEach(goals, id: \.id) { goal in
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
            StudyFormView(core: core, existingStudy: study)
        }
    }
}

#Preview {
    StudyDetailView(
        core: Core(),
        study: Study(
            id: "1",
            name: "Sample Study",
            description: "This is a sample study"
        )
    )
}
