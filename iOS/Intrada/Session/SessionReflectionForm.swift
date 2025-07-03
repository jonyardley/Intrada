import SwiftUI
import SharedTypes

struct SessionReflectionForm: View {
    let sessionId: String
    @ObservedObject var core: Core
    @Binding var isPresented: Bool
    @State private var notes: String = ""
    
    private var session: PracticeSessionView? {
        core.view.sessions.first { $0.id == sessionId }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Session Reflection")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Session Reflection")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    if !notes.isEmpty {
                        core.update(.editSessionNotes(sessionId, notes))
                    }
                    isPresented = false
                }
            )
            .onAppear {
                if let session = session {
                    notes = session.notes ?? ""
                }
            }
        }
    }
}

#Preview {
    SessionReflectionForm(
        sessionId: "1",
        core: Core(),
        isPresented: .constant(true)
    )
} 
