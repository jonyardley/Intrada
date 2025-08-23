//
//  QuickStartSessionView.swift
//  Intrada
//
//  Created by Assistant on 30/05/2025.
//

import SharedTypes
import SwiftUI

struct QuickStartSessionView: View {
    @ObservedObject var core: Core
    @Binding var isPresented: Bool
    @State private var intention: String = ""
    @State private var selectedGoals: Set<String> = []
    @State private var useRecentGoals = true

    var body: some View {
        NavigationView {
            VStack(spacing: Theme.Spacing.extraLarge) {
                // Header
                VStack(spacing: Theme.Spacing.small) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.primary)

                    Text("Quick Start Session")
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Colors.text)

                    Text("Get started with minimal setup")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding(.top, Theme.Spacing.extraLarge)

                // Intention Input
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("What's your intention?")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.text)

                    TextField("e.g., Practice scales, Work on dynamics...", text: $intention)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.done)
                }
                .padding(.horizontal, Theme.Spacing.large)

                // Goals Selection
                VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                    Text("Goals")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.text)
                        .padding(.horizontal, Theme.Spacing.large)

                    if core.view.goals.isEmpty {
                        Text("No goals available. You can add goals later.")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .padding(.horizontal, Theme.Spacing.large)
                    } else {
                        // Smart goal selection
                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                            Toggle("Use recent goals", isOn: $useRecentGoals)
                                .padding(.horizontal, Theme.Spacing.large)

                            if useRecentGoals {
                                Text("We'll automatically select your most recently used goals")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .padding(.horizontal, Theme.Spacing.large)
                            } else {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                                        ForEach(core.view.goals, id: \.id) { goal in
                                            Toggle(goal.name, isOn: binding(for: goal))
                                                .padding(.horizontal, Theme.Spacing.large)
                                        }
                                    }
                                }
                                .frame(maxHeight: 150)
                            }
                        }
                    }
                }

                Spacer()

                // Action Buttons
                VStack(spacing: Theme.Spacing.medium) {
                    Button(action: createAndStartSession) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Session")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(intention.isEmpty)

                    Button("Just Create Session") {
                        createSession(startImmediately: false)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(intention.isEmpty)
                }
                .padding(.horizontal, Theme.Spacing.large)
                .padding(.bottom, Theme.Spacing.extraLarge)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                }
            )
        }
        .onAppear {
            setupSmartDefaults()
        }
    }

    // MARK: - Actions

    private func createAndStartSession() {
        createSession(startImmediately: true)
    }

    private func createSession(startImmediately: Bool) {
        let goalIds = useRecentGoals ? getRecentGoalIds() : Array(selectedGoals)
        let sessionId = UUID().uuidString

        let session = PracticeSession(
            id: sessionId,
            goalIds: goalIds,
            intention: intention,
            notes: nil,
            studySessions: [],
            activeStudySessionId: nil,
            state: .notStarted
        )

        // Create session
        core.update(.session(.createSession(session)))

        // Start immediately if requested
        if startImmediately {
            let startTime = Date().ISO8601Format()
            core.update(.session(.startSession(sessionId, startTime)))
        }

        isPresented = false

        // Navigate to the session
        if let tabView = findTabView() {
            // Switch to Sessions tab and navigate to the new session
            // This is a simplified approach - in a real app you might use a more sophisticated navigation coordinator
        }
    }

    // MARK: - Helper Methods

    private func setupSmartDefaults() {
        // Set up smart defaults based on user's recent activity
        if let recentSession = core.view.sessions.first {
            // Pre-populate with similar intention if recent session exists
            if intention.isEmpty {
                intention = recentSession.intention
            }
        }
    }

    private func getRecentGoalIds() -> [String] {
        // Get goals from most recent sessions
        let recentGoalIds = core.view.sessions
            .prefix(3)
            .flatMap(\.goalIds)

        // Remove duplicates and return
        return Array(Set(recentGoalIds))
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

    private func findTabView() -> TabView<String, AnyView>? {
        // Helper to find parent TabView - simplified for demo
        // In a real app, you'd use proper navigation coordination
        nil
    }
}

#Preview {
    QuickStartSessionView(core: Core(), isPresented: .constant(true))
}
