import SwiftUI
import SharedTypes

struct ActiveSessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var core: Core
    let sessionId: String
    @State private var showingReflectionForm = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var session: PracticeSessionView? {
        core.view.sessions.first(where: { $0.id == sessionId })
    }
    
    var body: some View {
        Group {
            if let session = session {
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
        .sheet(isPresented: $showingReflectionForm, onDismiss: {
            dismiss()
        }) {
            SessionReflectionForm(
                sessionId: sessionId,
                core: core,
                isPresented: $showingReflectionForm
            )
        }
        .alert("Session Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
}

// MARK: - Session Active View (Simplified)
private struct SessionActiveView: View {
    let session: PracticeSessionView
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
            
            // Pause/Resume button
            if core.view.canPauseSession {
                Button("Pause") {
                    handlePauseSession()
                }
                .foregroundColor(.orange)
            } else if core.view.canResumeSession {
                Button("Resume") {
                    handleResumeSession()
                }
                .foregroundColor(.blue)
            }
            
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
    
    private func handlePauseSession() {
        guard let session = core.view.currentSession else {
            onError("No active session found")
            return
        }
        
        let timestamp = Date().ISO8601Format()
        core.update(.pauseSession(session.id, timestamp))
    }
    
    private func handleResumeSession() {
        guard let session = core.view.currentSession else {
            onError("No active session found")
            return
        }
        
        let timestamp = Date().ISO8601Format()
        core.update(.resumeSession(session.id, timestamp))
    }
    
    private func handleEndSession() {
        guard let session = core.view.currentSession else {
            onError("No active session found")
            return
        }
        
        let timestamp = Date().ISO8601Format()
        core.update(.endSession(session.id, timestamp))
    }
}

// MARK: - Session Header View
private struct SessionHeaderView: View {
    let session: PracticeSessionView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.intention)
                .font(.title)
                .fontWeight(.bold)
            
            SessionStateView(state: session.state)
        }
        .padding(.horizontal)
    }
}

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
            return "circle"
        case .started:
            return "play.circle.fill"
        case .paused:
            return "pause.circle.fill" 
        case .ended:
            return "checkmark.circle.fill"
        }
    }
    
    private var stateColor: Color {
        switch state {
        case .notStarted:
            return .gray
        case .started:
            return .green
        case .paused:
            return .orange
        case .ended:
            return .blue
        }
    }
    
    private var stateDescription: String {
        switch state {
        case .notStarted:
            return "Ready to start"
        case .started:
            return "In progress"
        case .paused:
            return "Paused"
        case .ended:
            return "Completed"
        }
    }
}

// MARK: - Session Timer View (Simplified)
private struct SessionTimerView: View {
    @ObservedObject var core: Core
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Timer")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let elapsedTime = core.view.currentSessionElapsedTime {
                        Text(elapsedTime)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
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
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        // Update every second to refresh the elapsed time
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
            // Force a view refresh by updating the current time
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Session Goals View
private struct SessionGoalsView: View {
    let session: PracticeSessionView
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
            
            if !goal.exerciseIds.isEmpty {
                Text("Exercises")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                
                let exercises = core.view.exercises.filter { exercise in
                    goal.exerciseIds.contains(exercise.id)
                }
                
                ForEach(exercises, id: \.id) { exercise in
                    ExerciseRowView(exercise: exercise, core: core)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Exercise Row View
private struct ExerciseRowView: View {
    let exercise: Exercise
    let core: Core
    
    var body: some View {
        NavigationLink(destination: ExerciseDetailView(core: core, exercise: exercise)) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.subheadline)
                    if let description = exercise.description {
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
