import SharedTypes
import SwiftUI

struct ActiveSessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var core: Core
    let sessionId: String
    @State private var showingReflectionForm = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private var session: PracticeSession? {
        core.view.sessions.first(where: { $0.id == sessionId })
    }

    var body: some View {
        Group {
            if let session {
                SessionActiveView(
                    session: session,
                    core: core,
                    onSessionEnd: {
                        showingReflectionForm = true
                    },
                    onError: { message in
                        errorMessage = message
                        showingError = true
                    }
                )
            } else {
                SessionNotFoundView {
                    dismiss()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingReflectionForm) {
            SessionReflectionForm(
                sessionId: sessionId,
                core: core,
                isPresented: $showingReflectionForm
            )
        }
        .onDisappear {
            dismiss()
        }
        .alert("Session Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // If session is already in pendingReflection state when view appears, show reflection form
            if let session, case .pendingReflection = session.state {
                showingReflectionForm = true
            }
        }
        .onChange(of: session?.state) { newState in
            // Also handle state changes while the view is active
            if let newState, case .pendingReflection = newState {
                showingReflectionForm = true
            }
        }
    }
}

// MARK: - Session Active View (Simplified)

private struct SessionActiveView: View {
    let session: PracticeSession
    @ObservedObject var core: Core
    let onSessionEnd: () -> Void
    let onError: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SessionControlsView(
                core: core,
                onSessionEnd: onSessionEnd,
                onError: onError
            )

            SessionHeaderView(session: session)
            SessionTimerView(core: core)
            SessionGoalsView(session: session, core: core)
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Session Controls View (Simplified)

private struct SessionControlsView: View {
    @ObservedObject var core: Core
    let onSessionEnd: () -> Void
    let onError: (String) -> Void

    var body: some View {
        HStack {
            Spacer()

            // End session button
            if core.view.canEndSession {
                Button("End Session") {
                    handleEndSession()
                    onSessionEnd()
                }
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
    }

    private func handleEndSession() {
        guard let session = core.view.currentSession else {
            onError("No active session found")
            return
        }

        let timestamp = Date().ISO8601Format()
        core.update(.session(.endSession(session.id, timestamp)))
    }
}

// MARK: - Session Header View

// MARK: - Session State View (Type-safe state display)

private struct SessionStateView: View {
    let state: SessionState

    var body: some View {
        HStack {
            Image(systemName: stateIcon)
                .foregroundColor(stateColor)
            Text(stateDescription)
                .font(.subheadline)
                .foregroundColor(stateColor)
        }
    }

    private var stateIcon: String {
        switch state {
        case .notStarted:
            "circle"
        case .started:
            "play.circle.fill"
        case .pendingReflection:
            "pause.circle.fill"
        case .ended:
            "checkmark.circle.fill"
        }
    }

    private var stateColor: Color {
        switch state {
        case .notStarted:
            .gray
        case .started:
            .green
        case .pendingReflection:
            .orange
        case .ended:
            .blue
        }
    }

    private var stateDescription: String {
        switch state {
        case .notStarted:
            "Ready to start"
        case .started:
            "In progress"
        case .pendingReflection:
            "Waiting for reflection"
        case .ended:
            "Completed"
        }
    }
}

// MARK: - Session Timer View (Dynamic)

private struct SessionTimerView: View {
    @ObservedObject var core: Core

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Timer")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let session = core.view.currentSession {
                        DynamicTimerView(
                            session: session,
                            fontSize: .system(size: 48, weight: .bold, design: .monospaced),
                            textColor: .blue
                        )
                    } else {
                        Text("00:00:00")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
}

// MARK: - Session Goals View

private struct SessionGoalsView: View {
    let session: PracticeSession
    let core: Core

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Practice Goals")
                .font(.headline)

            let goals = core.view.goals.filter { goal in
                session.goalIds.contains(goal.id)
            }

            if goals.isEmpty {
                EmptyGoalsView()
            } else {
                ForEach(goals, id: \.id) { goal in
                    GoalSectionView(goal: goal, core: core)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Empty Goals View

private struct EmptyGoalsView: View {
    var body: some View {
        HStack {
            Image(systemName: "target")
                .foregroundColor(.gray)
            Text("No goals selected for this session")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Goal Section View

private struct GoalSectionView: View {
    let goal: PracticeGoal
    let core: Core

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(.headline)
                    if let description = goal.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }

            if !goal.studyIds.isEmpty {
                Text("Studies")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)

                let studies = core.view.studies.filter { study in
                    goal.studyIds.contains(study.id)
                }

                ForEach(studies, id: \.id) { study in
                    StudyRowView(study: study, core: core)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Study Row View

private struct StudyRowView: View {
    let study: Study
    let core: Core

    var body: some View {
        NavigationLink(destination: StudyDetailView(core: core, study: study)) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(study.name)
                        .font(.subheadline)
                    if let description = study.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Session Not Found View

private struct SessionNotFoundView: View {
    let onDismiss: () -> Void

    var body: some View {
        Color.clear
            .onAppear {
                onDismiss()
            }
            .alert("Session Not Found", isPresented: .constant(true)) {
                Button("OK") {
                    onDismiss()
                }
            } message: {
                Text("The session you're looking for doesn't exist or has been deleted.")
            }
    }
}

#Preview {
    let core = Core()
    let sessionId = core.view.sessions.first?.id ?? "preview-session-id"
    ActiveSessionDetailView(
        core: core,
        sessionId: sessionId
    )
}
