//
//  SessionFormView.swift
//  Intrada
//
//  Created by Jon Yardley on 30/05/2025.
//

import SwiftUI
import SharedTypes

struct SessionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var core: Core
    @Binding var isPresented: Bool
    let existingSessionId: String?
    let onSessionCreated: ((String) -> Void)?
    
    @State private var intention: String
    @State private var notes: String
    @State private var selectedGoals: Set<String>
    @State private var showingGoalForm = false
    
    init(core: Core, isPresented: Binding<Bool>, existingSessionId: String? = nil, onSessionCreated: ((String) -> Void)? = nil) {
        self.core = core
        self._isPresented = isPresented
        self.existingSessionId = existingSessionId
        self.onSessionCreated = onSessionCreated
        
        // Initialize state variables with existing session data if available
        let existingSession = existingSessionId.flatMap { id in
            core.view.sessions.first { $0.id == id }
        }
        
        _intention = State(initialValue: existingSession?.intention ?? "")
        _notes = State(initialValue: existingSession?.notes ?? "")
        _selectedGoals = State(initialValue: Set(existingSession?.goalIds ?? []))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Session Details")) {
                    TextField("What's your intention for this session?", text: $intention)
                }
                
                if let existingSession = existingSessionId.flatMap({ id in
                    core.view.sessions.first { $0.id == id }
                }), existingSession.isEnded {
                    Section(header: Text("Reflection Notes")) {
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                    }
                }
                
                Section(header: Text("Related Goals")) {
                    Button(action: {
                        showingGoalForm = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color(red: 79/255, green: 70/255, blue: 229/255))
                            Text("Add New Goal")
                                .foregroundColor(Color(red: 79/255, green: 70/255, blue: 229/255))
                        }
                    }
                    
                    if core.view.goals.isEmpty {
                        Text("No goals available")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(core.view.goals, id: \.id) { goal in
                            Toggle(
                                goal.name,
                                isOn: binding(for: goal)
                            )
                        }
                    }
                }
            }
            .navigationTitle(existingSessionId == nil ? "New Session" : "Edit Session")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    if let existingSessionId = existingSessionId {
                        // Editing existing session - let the core handle state preservation
                        core.update(.editSessionFields(
                            session_id: existingSessionId,
                            goal_ids: Array(selectedGoals),
                            intention: intention,
                            notes: notes.isEmpty ? nil : notes
                        ))
                        isPresented = false
                    } else {
                        // Creating a new session - always starts as NotStarted
                        let sessionId = UUID().uuidString
                        let sessionData = SessionData(
                            id: sessionId,
                            goalIds: Array(selectedGoals),
                            intention: intention,
                            notes: notes.isEmpty ? nil : notes,
                            exerciseRecords: []
                        )
                        let notStartedSession = NotStartedSession(data: sessionData)
                        let session = PracticeSession.notStarted(notStartedSession)
                        
                        core.update(.addSession(session))
                        isPresented = false
                        onSessionCreated?(sessionId)
                    }
                }
                    .disabled(intention.isEmpty)
            )
            .sheet(isPresented: $showingGoalForm) {
                GoalFormView(core: core)
            }
        }
    }
    
    private func binding(for goal: PracticeGoal) -> Binding<Bool> {
        Binding(
            get: { selectedGoals.contains(goal.id) },
            set: { isSelected in
                if isSelected {
                    selectedGoals.insert(goal.id)
                } else {
                    selectedGoals.remove(goal.id)
                }
            }
        )
    }
}

#Preview {
    SessionFormView(core: Core(), isPresented: .constant(true))
} 
