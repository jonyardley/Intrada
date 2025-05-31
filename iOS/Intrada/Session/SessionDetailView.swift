import SwiftUI
import SharedTypes

struct SessionDetailView: View {
    @ObservedObject var core: Core
    let sessionId: String
    @State private var showingEditForm = false
    @State private var showingReflectionForm = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isEndingSession = false
    
    private var session: PracticeSession {
        core.view.sessions.first(where: { $0.id == sessionId }) ?? PracticeSession(
            id: sessionId,
            goalIds: [],
            intention: "",
            startTime: nil,
            endTime: nil,
            notes: nil,
            duration: nil
        )
    }
    
    var isActive: Bool {
        session.startTime != nil && session.endTime == nil
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sessionHeaderView
                
                if isActive {
                    activeSessionView
                } else {
                    durationView
                }
                
                notesView
                sessionTimesView
                relatedGoalsView
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
            if isActive {
                startTimer()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: core.view.sessions) { _ in
            if !isActive {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private var sessionHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.intention)
                .font(.title)
                .fontWeight(.bold)
        }
        .padding(.horizontal)
    }
    
    private var notesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
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
                Text("No notes")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private var activeSessionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Session")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(formatElapsedTime(elapsedTime))
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
        .onChange(of: isEndingSession) { newValue in
            if newValue {
                showingReflectionForm = true
                isEndingSession = false
            }
        }
    }
    
    private var durationView: some View {
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
    
    private var sessionTimesView: some View {
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
    
    private var relatedGoalsView: some View {
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
                    NavigationLink(destination: GoalDetailView(core: core, goal: goal)) {
                        HStack {
                            Text(goal.name)
                            Spacer()
                            if let description = goal.description {
                                Text(description)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func endSession() {
        timer?.invalidate()
        timer = nil
        elapsedTime = 0
        core.update(.endSession(session.id, Date().ISO8601Format()))
        showingReflectionForm = true
    }
    
    private func startTimer() {
        guard let startTime = session.startTime,
              let startDate = ISO8601DateFormatter().date(from: startTime) else { return }
        
        elapsedTime = Date().timeIntervalSince(startDate)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(startDate)
        }
    }
    
    private func formatElapsedTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
