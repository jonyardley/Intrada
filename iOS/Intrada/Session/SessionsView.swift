//
//  SessionsView.swift
//  Intrada
//
//  Created by Jon Yardley on 30/05/2025.
//

import SwiftUI
import SharedTypes

struct SessionsView: View {
    @ObservedObject var core: Core
    @State private var showingAddForm = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    private var activeSession: PracticeSession? {
        core.view.sessions.first { $0.startTime != nil && $0.endTime == nil }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Your Sessions")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: { showingAddForm = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                }
                .padding(.horizontal)
                
                if let activeSession = activeSession {
                    ActiveSessionView(session: activeSession, core: core)
                        .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent practice sessions")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    if core.view.sessions.isEmpty {
                        Text("No sessions yet")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        ForEach(core.view.sessions.filter { $0.endTime != nil }, id: \.id) { session in
                            SessionRow(session: session)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddForm) {
            SessionFormView(core: core, isPresented: $showingAddForm)
        }
    }
}

struct ActiveSessionView: View {
    let session: PracticeSession
    @ObservedObject var core: Core
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Session")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(session.intention)
                    .font(.headline)
                
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text(formatElapsedTime(elapsedTime))
                        .font(.title3)
                        .monospacedDigit()
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button(action: stopSession) {
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
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        guard let startTime = session.startTime,
              let startDate = ISO8601DateFormatter().date(from: startTime) else { return }
        
        elapsedTime = Date().timeIntervalSince(startDate)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(startDate)
        }
    }
    
    private func stopSession() {
        timer?.invalidate()
        core.update(.endSession(session.id, Date().ISO8601Format()))
    }
    
    private func formatElapsedTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct SessionRow: View {
    let session: PracticeSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.intention)
                .font(.headline)
            
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            HStack {
                if let startTime = session.startTime {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text(formatDateAndTime(startTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if let duration = session.duration {
                    Text(duration)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
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

struct SessionFormView: View {
	@ObservedObject var core: Core
	@Binding var isPresented: Bool
	
	@State private var intention: String = ""
	@State private var notes: String = ""
	@State private var selectedGoals: Set<String> = []
	
	var body: some View {
		NavigationView {
			Form {
				Section(header: Text("Session Details")) {
					TextField("What's your intention for this session?", text: $intention)
					TextEditor(text: $notes)
						.frame(height: 100)
				}
				
				Section(header: Text("Related Goals")) {
                    Text("Coming soon")
				}
			}
			.navigationTitle("New Session")
			.navigationBarItems(
				leading: Button("Cancel") {
					isPresented = false
				},
				trailing: Button("Start") {
					let session = PracticeSession(
						id: UUID().uuidString,
						goalIds: Array(selectedGoals),
						intention: intention,
						startTime: Date().ISO8601Format(),
						endTime: nil,
						notes: notes.isEmpty ? nil : notes,
                        duration: nil
					)
					core.update(.addSession(session))
					isPresented = false
				}
					.disabled(intention.isEmpty)
			)
		}
	}
}

#Preview {
    SessionsView(core: Core())
}

