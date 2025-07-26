import SwiftUI
import SharedTypes

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var core: Core
    let sessionId: String
    @State private var showingEditForm = false
    @State private var showingReflectionForm = false
    @State private var showingError = false
    @State private var isLoading = false
    

    private var session: PracticeSessionView? {
        core.view.sessions.first(where: { $0.id == sessionId })

    }
    
    var body: some View {
        Group {
            if let session = session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        sessionHeaderView(session: session)
                        sessionSummaryView(session: session)
                        notesView(session: session)
                        sessionTimesView(session: session)
                        relatedGoalsView(session: session)
                    }
                    .padding(.vertical)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        // State transition button
                        stateTransitionButton(for: session)
                        
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
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading session...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear
                    .onAppear {
                        showingError = true
                    }
            }
        }
        .onAppear {
            if session == nil {
                isLoading = true
                print("🔍 SessionDetailView: Looking for session with ID: \(sessionId)")
                print("🔍 SessionDetailView: Available sessions: \(core.view.sessions.map { "\($0.id): \($0.intention)" })")
                
                // Give the session time to load, then show error if still not found
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if session == nil {
                        print("❌ SessionDetailView: Session \(sessionId) still not found after 3 seconds")
                        isLoading = false
                        showingError = true
                    }
                }
            } else {
                print("✅ SessionDetailView: Found session \(sessionId): \(session!.intention)")
            }
        }
        .onChange(of: core.view.sessions.count) { _ in
            // Session was loaded
            if session != nil {
                isLoading = false
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
    
    @ViewBuilder
    private func stateTransitionButton(for session: PracticeSessionView) -> some View {
        switch session.state {
        case .notStarted:
            Button {
                let startTime = Date().ISO8601Format()
                core.update(.session(.startSession(session.id, startTime)))
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                    Text("Start")
                }
            }
            .foregroundColor(.green)
            
        case .started:
            Button {
                let endTime = Date().ISO8601Format()
                core.update(.session(.endSession(session.id, endTime)))
                handleSessionEnd(session)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                    Text("End")
                }
            }
            .foregroundColor(.red)
            
        case .ended:
            // No action button for ended sessions, just show completed status
            EmptyView()
        }
    }
    
    private func handleSessionEnd(_ session: PracticeSessionView) {
        // Show reflection form when session ends
        showingReflectionForm = true
    }
    
    private func sessionHeaderView(session: PracticeSessionView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.intention)
                .font(.title)
                .fontWeight(.bold)
            
            // Session state indicator
            HStack {
                Image(systemName: sessionStateIcon(for: session.state))
                    .foregroundColor(sessionStateColor(for: session.state))
                Text(sessionStateDescription(for: session.state))
                    .font(.subheadline)
                    .foregroundColor(sessionStateColor(for: session.state))
            }
        }
        .padding(.horizontal)
    }
    
    private func sessionStateIcon(for state: SessionState) -> String {
        switch state {
        case .notStarted:
            return "circle"
        case .started:
            return "play.circle.fill"
        case .ended:
            return "checkmark.circle.fill"
        }
    }
    
    private func sessionStateColor(for state: SessionState) -> Color {
        switch state {
        case .notStarted:
            return .orange
        case .started:
            return .green
        case .ended:
            return .blue
        }
    }
    
    private func sessionStateDescription(for state: SessionState) -> String {
        switch state {
        case .notStarted:
            return "Ready to start"
        case .started:
            return "In progress"
        case .ended:
            return "Completed"
        }
    }
    
    private func sessionSummaryView(session: PracticeSessionView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Summary")
                .font(.headline)
            
            if let duration = session.duration {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    Text(duration)
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func notesView(session: PracticeSessionView) -> some View {
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
    
    private func sessionTimesView(session: PracticeSessionView) -> some View {
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
    
    private func relatedGoalsView(session: PracticeSessionView) -> some View {
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
                        let studies = core.view.studies.filter { study in
                            goal.studyIds.contains(study.id)
                        }
                        
                        if studies.isEmpty {
                            Text("No studies added")
                                .foregroundColor(.gray)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(studies, id: \.id) { study in
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
