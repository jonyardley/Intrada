import SharedTypes
import SwiftUI

struct GoalFormView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var core: Core
  let existingGoal: PracticeGoal?

  @State private var name: String
  @State private var description: String
  @State private var targetDate: Date
  @State private var tempoTarget: String
  @State private var selectedExercises: Set<String>

  init(core: Core, existingGoal: PracticeGoal? = nil) {
    self.core = core
    self.existingGoal = existingGoal
    
    // Initialize state variables with existing goal data if available
    _name = State(initialValue: existingGoal?.name ?? "")
    _description = State(initialValue: existingGoal?.description ?? "")
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let date = existingGoal?.target_date.flatMap { dateFormatter.date(from: $0) } ?? Date()
    _targetDate = State(initialValue: date)
    
    _tempoTarget = State(initialValue: existingGoal?.tempo_target.map(String.init) ?? "")
    _selectedExercises = State(initialValue: Set(existingGoal?.exercise_ids ?? []))
  }

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Goal Details")) {
          TextField("Name", text: $name)
          TextField("Description", text: $description, axis: .vertical)
            .lineLimit(3...6)
        }

        Section(header: Text("Target Date")) {
          DatePicker("Select Date", selection: $targetDate, displayedComponents: [.date])
        }

        Section(header: Text("Tempo Target (BPM)")) {
          TextField("Enter tempo", text: $tempoTarget)
            .keyboardType(.numberPad)
        }

        Section(header: Text("Exercises")) {
          ForEach(core.view.exercises, id: \.id) { exercise in
            Toggle(
              exercise.name,
              isOn: binding(for: exercise)
            )
          }
        }
      }
      .navigationTitle(existingGoal == nil ? "New Goal" : "Edit Goal")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let targetDateString = dateFormatter.string(from: targetDate)

            let goal = PracticeGoal(
              id: existingGoal?.id ?? UUID().uuidString,
              name: name,
              description: description.isEmpty ? nil : description,
              status: existingGoal?.status ?? .notStarted,
              start_date: existingGoal?.start_date,
              target_date: targetDateString,
              exercise_ids: Array(selectedExercises),
              tempo_target: tempoTarget.isEmpty ? nil : UInt32(tempoTarget)
            )

            if existingGoal != nil {
              core.update(.editGoal(goal))
            } else {
              core.update(.addGoal(goal))
            }
            dismiss()
          }
        }
      }
    }
  }

  private func binding(for exercise: Exercise) -> Binding<Bool> {
    Binding(
      get: { selectedExercises.contains(exercise.id) },
      set: { isSelected in
        if isSelected {
          selectedExercises.insert(exercise.id)
        } else {
          selectedExercises.remove(exercise.id)
        }
      }
    )
  }
}

#Preview {
  GoalFormView(core: Core())
}
