//
//  SessionFormView.swift
//  Intrada
//
//  Created by Jon Yardley on 30/05/2025.
//

import SharedTypes
import SwiftUI

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
    @State private var goalSearchText = ""
    @State private var showValidationHints = false

    init(core: Core, isPresented: Binding<Bool>, existingSessionId: String? = nil, onSessionCreated: ((String) -> Void)? = nil) {
        self.core = core
        _isPresented = isPresented
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
                // Session Details Section
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        TextField("What's your intention for this session?", text: $intention, axis: .vertical)
                            .lineLimit(2 ... 4)
                            .textFieldStyle(.plain)

                        if showValidationHints, intention.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(Theme.Colors.warning)
                                Text("Please describe your session intention")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.warning)
                            }
                            .transition(.opacity)
                        } else if !intention.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(Theme.Colors.success)
                                Text("Looks good!")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.success)
                            }
                            .transition(.opacity)
                        }
                    }
                } header: {
                    Text("Session Details")
                } footer: {
                    Text("Describe what you want to focus on or achieve in this practice session.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                // Reflection Notes Section (only for ended sessions)
                if let existingSession = existingSessionId.flatMap({ id in
                    core.view.sessions.first { $0.id == id }
                }), case .ended = existingSession.state {
                    Section {
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                    } header: {
                        Text("Reflection Notes")
                    } footer: {
                        Text("How did the session go? What did you learn?")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }

                // Goals Selection Section
                Section {
                    // Add New Goal Button
                    Button(action: {
                        showingGoalForm = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.primary)
                            Text("Add New Goal")
                                .foregroundColor(Theme.Colors.primary)
                        }
                    }

                    // Goals List
                    if core.view.goals.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                            Text("No goals available")
                                .foregroundColor(Theme.Colors.textSecondary)
                            Text("Create your first goal to track your practice progress!")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    } else {
                        // Search field for many goals
                        if core.view.goals.count > 5 {
                            TextField("Search goals...", text: $goalSearchText)
                                .textFieldStyle(.plain)
                        }

                        // Filtered goals list
                        ForEach(filteredGoals, id: \.id) { goal in
                            GoalSelectionRow(
                                goal: goal,
                                isSelected: binding(for: goal)
                            )
                        }

                        // Selection summary
                        if !selectedGoals.isEmpty {
                            HStack {
                                Image(systemName: "target")
                                    .foregroundColor(Theme.Colors.primary)
                                Text("\(selectedGoals.count) goal\(selectedGoals.count == 1 ? "" : "s") selected")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("Related Goals")
                } footer: {
                    Text("Select goals that this session will help you work towards.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
            .navigationTitle(existingSessionId == nil ? "New Session" : "Edit Session")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    saveSession()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(intention.isEmpty)
            )
            .sheet(isPresented: $showingGoalForm) {
                GoalFormView(core: core)
            }
        }
        .onChange(of: intention) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showValidationHints = intention.isEmpty
            }
        }
    }

    // MARK: - Actions

    private func saveSession() {
        // Show validation hints if needed
        if intention.isEmpty {
            withAnimation(.easeInOut(duration: 0.3)) {
                showValidationHints = true
            }
            return
        }

        if let existingSessionId {
            // Editing existing session
            core.update(.session(.editSessionFields(
                session_id: existingSessionId,
                goal_ids: Array(selectedGoals),
                intention: intention,
                notes: notes.isEmpty ? nil : notes
            )))
            isPresented = false
        } else {
            // Creating a new session
            let sessionId = UUID().uuidString
            let session = PracticeSession(
                id: sessionId,
                goalIds: Array(selectedGoals),
                intention: intention,
                notes: notes.isEmpty ? nil : notes,
                studySessions: [],
                activeStudySessionId: nil,
                state: .notStarted
            )

            print("🆕 SessionFormView: Creating session with ID: \(sessionId)")
            core.update(.session(.createSession(session)))
            isPresented = false

            // Navigate immediately - session creation is optimistic and available instantly
            print("🚀 SessionFormView: Triggering navigation to session: \(sessionId)")
            onSessionCreated?(sessionId)
        }
    }

    // MARK: - Computed Properties

    private var filteredGoals: [PracticeGoal] {
        if goalSearchText.isEmpty {
            core.view.goals
        } else {
            core.view.goals.filter { goal in
                goal.name.localizedCaseInsensitiveContains(goalSearchText) ||
                    (goal.description?.localizedCaseInsensitiveContains(goalSearchText) ?? false)
            }
        }
    }

    // MARK: - Helper Methods

    private func binding(for goal: PracticeGoal) -> Binding<Bool> {
        Binding(
            get: { selectedGoals.contains(goal.id) },
            set: { isSelected in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isSelected {
                        selectedGoals.insert(goal.id)
                    } else {
                        selectedGoals.remove(goal.id)
                    }
                }
            }
        )
    }
}

// MARK: - Goal Selection Row Component

struct GoalSelectionRow: View {
    let goal: PracticeGoal
    @Binding var isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                Text(goal.name)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.text)

                if let description = goal.description {
                    Text(description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }

                // Goal status badge
                HStack {
                    StatusBadge(status: goal.status)

                    if let targetDate = goal.targetDate {
                        DateStatusView(targetDate: targetDate)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: $isSelected)
                .toggleStyle(CheckboxToggleStyle())
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isSelected.toggle()
            }
        }
    }
}

// MARK: - Custom Checkbox Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .foregroundColor(configuration.isOn ? Theme.Colors.primary : Theme.Colors.textSecondary)
                .font(.title2)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

#Preview {
    SessionFormView(core: Core(), isPresented: .constant(true))
}
