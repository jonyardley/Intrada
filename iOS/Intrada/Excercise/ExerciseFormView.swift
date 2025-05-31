import SwiftUI
import SharedTypes

struct ExerciseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var core: Core
    let existingExercise: Exercise?
    
    @State private var name: String
    @State private var description: String
    
    init(core: Core, existingExercise: Exercise? = nil) {
        self.core = core
        self.existingExercise = existingExercise
        
        // Initialize state variables with existing exercise data if available
        _name = State(initialValue: existingExercise?.name ?? "")
        _description = State(initialValue: existingExercise?.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise Details")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existingExercise == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    let exercise = Exercise(
                        id: existingExercise?.id ?? UUID().uuidString,
                        name: name,
                        description: description.isEmpty ? nil : description
                    )
                    
                    if existingExercise != nil {
                        core.update(.editExercise(exercise))
                    } else {
                        core.update(.addExercise(exercise))
                    }
                    dismiss()
                }
            )
        }
    }
}

#Preview {
    ExerciseFormView(core: Core())
} 