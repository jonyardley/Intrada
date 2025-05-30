import SwiftUI
import SharedTypes

struct GoalDetailView: View {
    @ObservedObject var core: Core
    let goal: PracticeGoal
    @State private var showingEditForm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Goal Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(goal.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let description = goal.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                // Target Date
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Date")
                        .font(.headline)
                    
                    if let targetDate = goal.target_date {
                        Text(targetDate)
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                
                // Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.headline)
                    
                    StatusBadge(status: goal.status)
                }
                .padding(.horizontal)
                
                // Associated Exercises
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercises")
                        .font(.headline)
                    
                    ForEach(core.view.exercises.filter { exercise in
                        goal.exercise_ids.contains(exercise.id)
                    }, id: \.id) { exercise in
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            if let description = exercise.description {
                                Text(description)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
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

#Preview {
    GoalDetailView(
        core: Core(),
        goal: PracticeGoal(
            id: "1",
            name: "Sample Goal",
            description: "This is a sample goal",
            status: .inProgress,
            start_date: nil,
            target_date: "2025-05-01",
            exercise_ids: [],
            tempo_target: nil
        )
    )
} 