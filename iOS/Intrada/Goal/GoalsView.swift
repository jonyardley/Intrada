import SharedTypes
import SwiftUI

struct GoalsView: View {
  @ObservedObject var core: Core
  @State private var showingGoalForm = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Text("Your Goals")
            .font(.largeTitle)
            .fontWeight(.bold)

          Spacer()

          Button(action: {
            showingGoalForm = true
          }) {
            Image(systemName: "plus.circle.fill")
              .font(.title)
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
            NavigationLink(destination: GoalDetailView(core: core, goal: goal)) {
              GoalCard(goal: goal)
                .padding(.horizontal)
            }
            .buttonStyle(PlainButtonStyle())
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
        if let targetDate = goal.targetDate {
          dateStatusView(targetDate: targetDate)
        }

        Spacer()

        StatusBadge(status: goal.status)
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(10)
  }

  private func dateStatusView(targetDate: String) -> some View {
    let calendar = Calendar.current
    let today = Date()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    if let targetDateObj = dateFormatter.date(from: targetDate) {
      let components = calendar.dateComponents([.day], from: today, to: targetDateObj)
      if let days = components.day {
        if days < 0 {
          return HStack(spacing: 4) {
            Image(systemName: "calendar")
              .foregroundColor(.red)
            Text("\(targetDate) - \(abs(days)) days ago")
              .font(.caption)
              .foregroundColor(.red)
          }
        } else {
          return HStack(spacing: 4) {
            Image(systemName: "calendar")
              .foregroundColor(.accentColor)
            Text("\(targetDate) - \(days) days to go")
              .font(.caption)
              .foregroundColor(.gray)
          }
        }
      }
    }
    return HStack(spacing: 4) {
      Image(systemName: "calendar")
        .foregroundColor(.gray)
      Text("Invalid date")
        .font(.caption)
        .foregroundColor(.gray)
    }
  }
}

struct StatusBadge: View {
  let status: GoalStatus

  var body: some View {
    Text(statusText)
      .font(.caption)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(statusColor)
      .foregroundColor(.white)
      .cornerRadius(8)
  }

  private var statusColor: Color {
    switch status {
    case .notStarted:
      return .gray
    case .inProgress:
      return .blue
    case .completed:
      return .green
    }
  }

  private var statusText: String {
    switch status {
    case .notStarted:
      return "Not Started"
    case .inProgress:
      return "In Progress"
    case .completed:
      return "Completed"
    }
  }
}

#Preview {
  GoalsView(core: Core())
}
