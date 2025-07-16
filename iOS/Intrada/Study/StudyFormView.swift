import SwiftUI
import SharedTypes

struct StudyFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var core: Core
    let existingStudy: Study?
    
    @State private var name: String
    @State private var description: String
    
    init(core: Core, existingStudy: Study? = nil) {
        self.core = core
        self.existingStudy = existingStudy
        
        // Initialize state variables with existing study data if available
        _name = State(initialValue: existingStudy?.name ?? "")
        _description = State(initialValue: existingStudy?.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Study Details")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existingStudy == nil ? "New Study" : "Edit Study")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    let study = Study(
                        id: existingStudy?.id ?? UUID().uuidString,
                        name: name,
                        description: description.isEmpty ? nil : description
                    )
                    
                    if existingStudy != nil {
                        core.update(.study(.editStudy(study)))
                    } else {
                        core.update(.study(.addStudy(study)))
                    }
                    dismiss()
                }
            )
        }
    }
}

#Preview {
    StudyFormView(core: Core())
} 