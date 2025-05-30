import SwiftUI
import SharedTypes

struct GoalDetailView: View {
    @ObservedObject var core: Core
    let goal: PracticeGoal
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var editedName: String
    @State private var editedDescription: String
    @State private var editedTargetDate: Date
    
    init(core: Core, goal: PracticeGoal) {
        self.core = core
        self.goal = goal
        _editedName = State(initialValue: goal.name)
        _editedDescription = State(initialValue: goal.description ?? "")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: goal.target_date ?? "") ?? Date()
        _editedTargetDate = State(initialValue: date)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Goal Header
                VStack(alignment: .leading, spacing: 8) {
                    if isEditing {
                        TextField("Goal Name", text: $editedName)
                            .font(.title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(goal.name)
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    
                    if isEditing {
                        TextField("Description", text: $editedDescription, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    } else if let description = goal.description {
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
                    
                    if isEditing {
                        DatePicker("Select Date", selection: $editedTargetDate, displayedComponents: [.date])
                    } else if let targetDate = goal.target_date {
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
                if isEditing {
                    Button("Save") {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        let targetDateString = dateFormatter.string(from: editedTargetDate)
                        
                        let updatedGoal = PracticeGoal(
                            id: goal.id,
                            name: editedName,
                            description: editedDescription.isEmpty ? nil : editedDescription,
                            status: goal.status,
                            start_date: goal.start_date,
                            target_date: targetDateString,
                            exercise_ids: goal.exercise_ids,
                            tempo_target: goal.tempo_target
                        )
                        
                        core.update(.addGoal(updatedGoal))
                        isEditing = false
                    }
                } else {
                    Button("Edit") {
                        isEditing = true
                    }
                }
            }
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