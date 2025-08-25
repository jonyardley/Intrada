import SharedTypes
import SwiftUI

struct GoalsView: View {
    @ObservedObject var core: Core
    @State private var showingGoalForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                ListHeader(title: "Your Goals") {
                    showingGoalForm = true
                }

                goalsSection
            }
            .padding(.vertical, Theme.Spacing.large)
        }
        .sheet(isPresented: $showingGoalForm) {
            GoalFormView(core: core)
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            if core.view.goals.isEmpty {
                EmptyStateView(message: "No goals yet")
            } else {
                ForEach(core.view.goals, id: \.id) { goal in
                    NavigationLink(destination: GoalDetailView(core: core, goal: goal)) {
                        GoalCard(goal: goal)
                            .padding(.horizontal, Theme.Spacing.large)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

#Preview {
    GoalsView(core: Core())
}
