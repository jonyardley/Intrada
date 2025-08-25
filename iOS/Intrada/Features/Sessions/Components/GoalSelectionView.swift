import SwiftUI
import SharedTypes

struct GoalSelectionView: View {
    @Binding var selectedGoalIds: Set<String>
    @Binding var showingGoalForm: Bool
    @Binding var searchText: String
    let availableGoals: [PracticeGoal]

    private var filteredGoals: [PracticeGoal] {
        if searchText.isEmpty {
            return availableGoals
        }
        return availableGoals.filter { goal in
            goal.name.localizedCaseInsensitiveContains(searchText) ||
            (goal.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text("Related Goals")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.text)

                Text("Select goals that this session will help you work towards.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.textSecondary)
            }

            // Add New Goal Button
            Button {
                showingGoalForm = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.Colors.primary)
                    Text("Add New Goal")
                        .foregroundColor(Theme.Colors.primary)
                }
            }

            // Goals List
            if availableGoals.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("No goals available")
                        .foregroundColor(Theme.Colors.textSecondary)
                    Text("Create your first goal to track your practice progress!")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            } else {
                // Search field for many goals
                if availableGoals.count > 5 {
                    TextField("Search goals...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                // Filtered goals list
                ForEach(filteredGoals, id: \.id) { goal in
                    Button {
                        if selectedGoalIds.contains(goal.id) {
                            selectedGoalIds.remove(goal.id)
                        } else {
                            selectedGoalIds.insert(goal.id)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.name)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.text)

                                if let description = goal.description {
                                    Text(description)
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            Image(systemName: selectedGoalIds.contains(goal.id) ?
                                  "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedGoalIds.contains(goal.id) ?
                                               Theme.Colors.primary : Theme.Colors.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if !selectedGoalIds.isEmpty {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(Theme.Colors.primary)
                        Text(
                            "\(selectedGoalIds.count) " +
                            "goal\(selectedGoalIds.count == 1 ? "" : "s") selected"
                        )
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}
