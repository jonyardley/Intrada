//
//  SessionFormView.swift
//  Intrada
//
//  Created by Jon Yardley on 30/05/2025.
//

import SwiftUI
import SharedTypes

struct SessionFormView: View {
    @ObservedObject var core: Core
    @Binding var isPresented: Bool
    
    @State private var intention: String = ""
    @State private var notes: String = ""
    @State private var selectedGoals: Set<String> = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Session Details")) {
                    TextField("What's your intention for this session?", text: $intention)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section(header: Text("Related Goals")) {
                    Text("Coming soon")
                }
            }
            .navigationTitle("New Session")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Start") {
                    let session = PracticeSession(
                        id: UUID().uuidString,
                        goalIds: Array(selectedGoals),
                        intention: intention,
                        startTime: Date().ISO8601Format(),
                        endTime: nil,
                        notes: notes.isEmpty ? nil : notes,
                        duration: nil
                    )
                    core.update(.addSession(session))
                    isPresented = false
                }
                    .disabled(intention.isEmpty)
            )
        }
    }
}

#Preview {
    SessionFormView(core: Core(), isPresented: .constant(true))
} 