import SharedTypes
import SwiftUI

struct GoalFormView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var core: Core

  @State private var name = ""
  @State private var description = ""
  @State private var targetDate = Date()
  @State private var tempoTarget = ""
  @State private var selectedExercises: Set<String> = []

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
      .navigationTitle("New Goal")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarItems(trailing: 
        Button("Save") {
          let dateFormatter = DateFormatter()
          dateFormatter.dateFormat = "yyyy-MM-dd"
          let targetDateString = dateFormatter.string(from: targetDate)

          let goal = PracticeGoal(
            id: UUID().uuidString,
            name: name,
            description: description.isEmpty ? nil : description,
            status: .notStarted,
            start_date: nil,
            target_date: targetDateString,
            exercise_ids: Array(selectedExercises),
            tempo_target: tempoTarget.isEmpty ? nil : UInt32(tempoTarget)
          )

          core.update(.addGoal(goal))
          dismiss()
        }
      )
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
