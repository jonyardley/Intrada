import SharedTypes
import SwiftUI

struct GoalsView: View {
  @ObservedObject var core: Core
  @State private var showingGoalForm = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
        ListHeader(title: "Your Goals") {
          showingGoalForm = true
        }

        goalsSection
      }
      .padding(.vertical, Theme.Spacing.lg)
    }
    .navigationTitle("Home")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showingGoalForm) {
      GoalFormView(core: core)
    }
  }
  
  private var goalsSection: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      SectionHeader(title: "Your Goals")
      
      if core.view.goals.isEmpty {
        EmptyStateView(message: "No goals yet")
      } else {
        ForEach(core.view.goals, id: \.id) { goal in
          NavigationLink(destination: GoalDetailView(core: core, goal: goal)) {
            GoalCard(goal: goal)
              .padding(.horizontal, Theme.Spacing.lg)
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
    }
  }
}

struct GoalCard: View {
  let goal: PracticeGoal

  var body: some View {
    Card {
      VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
        Text(goal.name)
          .font(Theme.Typography.headline)

        if let description = goal.description {
          Text(description)
            .font(Theme.Typography.subheadline)
            .foregroundColor(Theme.Colors.textSecondary)
        }

        HStack {
          if let targetDate = goal.targetDate {
            DateStatusView(targetDate: targetDate)
          }

          Spacer()

          StatusBadge(status: goal.status)
        }
      }
    }
  }
}


#Preview {
  GoalsView(core: Core())
}
