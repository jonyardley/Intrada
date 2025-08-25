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

    init(
        core: Core,
        isPresented: Binding<Bool>,
        existingSessionId: String? = nil,
        onSessionCreated: ((String) -> Void)? = nil
    ) {
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
            ScrollView {
                VStack(spacing: Theme.Spacing.extraLarge) {
                    // Header Section
                    VStack(spacing: Theme.Spacing.small) {
                        Image(systemName: existingSessionId == nil ? "plus.circle.fill" : "pencil.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.Colors.primary)

                        Text(existingSessionId == nil ? "New Practice Session" : "Edit Session")
                            .font(Theme.Typography.title)
                            .foregroundColor(Theme.Colors.text)

                        Text(
                            existingSessionId == nil
                                ? "Plan your next practice session"
                                : "Update session details"
                        )
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .padding(.top, Theme.Spacing.extraLarge)

                    VStack(spacing: Theme.Spacing.extraLarge) {
                        // Session Intention Input
                        Card {
                            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                    Text("Session Intention")
                                        .font(Theme.Typography.headline)
                                        .foregroundColor(Theme.Colors.text)

                                    Text("What do you want to focus on or achieve?")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }

                                TextField(
                                    "e.g., Practice scales, Work on dynamics...",
                                    text: $intention,
                                    axis: .vertical
                                )
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(2 ... 4)
                                .submitLabel(.done)

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
                        }

                        // Reflection Notes Section (only for ended sessions)
                        if let existingSession = existingSessionId.flatMap({ id in
                            core.view.sessions.first { $0.id == id }
                        }), case .ended = existingSession.state {
                            Card {
                                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                        Text("Reflection Notes")
                                            .font(Theme.Typography.headline)
                                            .foregroundColor(Theme.Colors.text)

                                        Text("How did the session go? What did you learn?")
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                    }

                                    TextEditor(text: $notes)
                                        .frame(minHeight: 100)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                            }
                        }

                        // Goals Selection Section
                        Card {
                            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                                    Text("Related Goals")
                                        .font(Theme.Typography.headline)
                                        .foregroundColor(Theme.Colors.text)

                                    Text("Select goals that this session will help you work towards.")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }

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
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }

                                    // Filtered goals list
                                    VStack(spacing: Theme.Spacing.small) {
                                        ForEach(filteredGoals, id: \.id) { goal in
                                            GoalSelectionRow(
                                                goal: goal,
                                                isSelected: binding(for: goal)
                                            )
                                        }
                                    }

                                    // Selection summary
                                    if !selectedGoals.isEmpty {
                                        HStack {
                                            Image(systemName: "target")
                                                .foregroundColor(Theme.Colors.primary)
                                            Text(
                                                "\(selectedGoals.count) goal\(selectedGoals.count == 1 ? "" : "s") selected"
                                            )
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                        }
                                    }
                                }
                            }
                        }

                        // Action Buttons
                        VStack(spacing: Theme.Spacing.medium) {
                            Button(action: saveSession) {
                                HStack {
                                    Image(systemName: existingSessionId == nil ? "plus" : "checkmark")
                                    Text(existingSessionId == nil ? "Create Session" : "Save Changes")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(intention.isEmpty)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.large)
                    .padding(.bottom, Theme.Spacing.extraLarge)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                }
            )
            .sheet(isPresented: $showingGoalForm) {
                GoalFormView(core: core)
            }
        }

        .onChange(of: intention) { _, _ in
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
