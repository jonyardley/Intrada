import SwiftUI
import SharedTypes

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var core: Core
    let sessionId: String
    @State private var showingEditForm = false
    @State private var showingReflectionForm = false
    @StateObject private var sessionTimer = SessionTimer.shared
    @State private var isEndingSession = false
    @State private var showingError = false
    
    private var session: PracticeSession? {
        core.view.sessions.first(where: { $0.id == sessionId })
    }
    
    var isActive: Bool {
        session?.startTime != nil && session?.endTime == nil
    }
    
    var body: some View {
        Group {
            if let session = session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        sessionHeaderView(session: session)
                        
                        if isActive {
                            activeSessionView(session: session)
                        } else {
                            durationView(session: session)
                        }
                        
                        if session.endTime != nil {
                            notesView(session: session)
                        }
                        
                        sessionTimesView(session: session)
                        relatedGoalsView(session: session)
                    }
                    .padding(.vertical)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") {
                            showingEditForm = true
                        }
                    }
                }
                .sheet(isPresented: $showingEditForm) {
                    SessionFormView(
                        core: core,
                        isPresented: $showingEditForm,
                        existingSessionId: sessionId
                    )
                }
                .sheet(isPresented: $showingReflectionForm) {
                    SessionReflectionForm(
                        sessionId: session.id,
                        core: core,
                        isPresented: $showingReflectionForm
                    )
                }
                .onAppear {
                    if isActive, let startTime = session.startTime {
                        sessionTimer.startTimer(startTime: startTime)
                    }
                }
                .onChange(of: core.view.sessions) { oldValue, newValue in
                    if !isActive {
                        sessionTimer.stopTimer()
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
    
    private func sessionHeaderView(session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.intention)
                .font(.title)
                .fontWeight(.bold)
        }
        .padding(.horizontal)
    }
    
    private func notesView(session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reflection notes")
                .font(.headline)
            
            if let notes = session.notes {
                Text(notes)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No reflection yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Take a moment to reflect on your practice - it helps deepen your learning!")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .italic()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private func activeSessionView(session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Session")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(sessionTimer.formatElapsedTime(sessionTimer.elapsedTime))
                        .font(.title3)
                        .monospacedDigit()
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button(action: endSession) {
                        Text("Stop Session")
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private func durationView(session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Duration")
                .font(.headline)
            
            if let duration = session.duration {
                Text(duration)
                    .font(.subheadline)
            }
        }
        .padding(.horizontal)
    }
    
    private func sessionTimesView(session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Times")
                .font(.headline)
            
            if let startTime = session.startTime {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.green)
                    Text(formatDateAndTime(startTime))
                        .font(.subheadline)
                }
            }
            
            if let endTime = session.endTime {
                HStack {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                    Text(formatDateAndTime(endTime))
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func relatedGoalsView(session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related Goals")
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
    
    private func formatDateAndTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            let displayFormatter = DateFormatter()
            
            if calendar.isDateInToday(date) {
                displayFormatter.dateFormat = "'Today at' h:mm a"
            } else if calendar.isDateInYesterday(date) {
                displayFormatter.dateFormat = "'Yesterday at' h:mm a"
            } else {
                displayFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
            }
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

#Preview {
    SessionDetailView(
        core: Core(),
        sessionId: "1"
    )
} 
