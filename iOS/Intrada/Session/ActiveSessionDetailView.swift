import SwiftUI
import SharedTypes

struct ActiveSessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var core: Core
    let sessionId: String
    @StateObject private var sessionTimer = SessionTimer.shared
    @State private var showingReflectionForm = false
    @State private var showingError = false
    
    private var session: PracticeSessionView? {
        core.view.sessions.first(where: { $0.id == sessionId })
    }
    
    var body: some View {
        Group {
            if let session = session {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        Button("End Session") {
                            endSession()
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    
                    sessionHeaderView(session: session)
                    activeSessionControls(session: session)
                    sessionGoalsView(session: session)
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showingReflectionForm, onDismiss: {
                    // Dismiss this view since the session is no longer active
                    dismiss()
                }) {
                    SessionReflectionForm(
                        sessionId: session.id,
                        core: core,
                        isPresented: $showingReflectionForm
                    )
                }
                        .onAppear {
            if case .started(let startTime) = session.state {
                sessionTimer.startTimer(startTime: startTime)
            }
        }
            } else {
                Color.clear
                    .onAppear {
                        showingError = true
                    }
            }
        }
        .alert("Session Not Found", isPresented: $showingError) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("The session you're looking for doesn't exist or has been deleted.")
        }
    }
    
    private func sessionHeaderView(session: PracticeSessionView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.intention)
                .font(.title)
                .fontWeight(.bold)
        }
        .padding(.horizontal)
    }
    
    private func activeSessionControls(session: PracticeSessionView) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Timer")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(sessionTimer.formatElapsedTime(sessionTimer.elapsedTime))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private func sessionGoalsView(session: PracticeSessionView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Practice Goals")
                .font(.headline)
            
            let goals = core.view.goals.filter { goal in
                session.goalIds.contains(goal.id)
            }
            
            if goals.isEmpty {
                Text("No goals associated")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                ForEach(goals, id: \.id) { goal in
                    Section {
                        let exercises = core.view.exercises.filter { exercise in
                            goal.exerciseIds.contains(exercise.id)
                        }
                        
                        if exercises.isEmpty {
                            Text("No exercises added")
                                .foregroundColor(.gray)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(exercises, id: \.id) { exercise in
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
                    } header: {
                        HStack {
                            Text(goal.name)
                                .font(.headline)
                            Spacer()
                            if let description = goal.description {
                                Text(description)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func endSession() {
        sessionTimer.stopTimer()
        if let session = session {
            core.update(.endSession(session.id, Date().ISO8601Format()))
            showingReflectionForm = true
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
