import SharedTypes
import SwiftUI

struct HomeView: View {
  @ObservedObject var core: Core
  @State private var showingGoalForm = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Text("Welcome")
            .font(.largeTitle)
            .fontWeight(.bold)

          Spacer()

          Button(action: {
            showingGoalForm = true
          }) {
            Image(systemName: "plus.circle.fill")
              .font(.title)
              .foregroundColor(.blue)
          }
        }
        .padding(.horizontal)

        // Goals section
        VStack(alignment: .leading, spacing: 10) {
          Text("Your Goals")
            .font(.title2)
            .fontWeight(.semibold)
            .padding(.horizontal)

          ForEach(core.view.goals, id: \.id) { goal in
            GoalCard(goal: goal)
              .padding(.horizontal)
          }
        }
      }
      .padding(.vertical)
    }
    .navigationTitle("Home")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showingGoalForm) {
      GoalFormView(core: core)
    }
  }
}

struct GoalCard: View {
  let goal: PracticeGoal

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(goal.name)
        .font(.headline)

      if let description = goal.description {
        Text(description)
          .font(.subheadline)
          .foregroundColor(.gray)
      }

      HStack {
        if let targetDate = goal.target_date {
          Label(targetDate, systemImage: "calendar")
            .font(.caption)
            .foregroundColor(.gray)
        }

        Spacer()

        StatusBadge(status: goal.status)
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(10)
  }
}

struct StatusBadge: View {
  let status: GoalStatus

  var body: some View {
    let (color, text) = statusInfo

    Text(text)
      .font(.caption)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(color)
      .foregroundColor(.white)
      .cornerRadius(8)
  }

  private var statusInfo: (Color, String) {
    switch status {
    case .notStarted:
      return (.gray, "Not Started")
    case .inProgress:
      return (.blue, "In Progress")
    case .completed:
      return (.green, "Completed")
    }
  }
}

#Preview {
  HomeView(core: Core())
}
