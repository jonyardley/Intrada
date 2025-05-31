import SwiftUI
import SharedTypes

struct SessionDetailView: View {
    @ObservedObject var core: Core
    let session: PracticeSession
    @State private var showingEditForm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Session Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.intention)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let notes = session.notes {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                // Session Duration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration")
                        .font(.headline)
                    
                    if let duration = session.duration {
                        Text(duration)
                            .font(.subheadline)
                    } else {
                        Text("Session in progress")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                // Session Times
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
                
                // Associated Goals
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
            SessionFormView(core: core, isPresented: $showingEditForm, existingSession: session)
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
        session: PracticeSession(
            id: "1",
            goalIds: [],
            intention: "Practice scales and arpeggios",
            startTime: "2025-05-01T12:00:00Z",
            endTime: "2025-05-01T12:30:00Z",
            notes: "Focused on C major and A minor",
            duration: "30m"
        )
    )
} 
