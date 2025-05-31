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
    @State private var showingReflectionForm = false
    @State private var sessionToReflect: PracticeSession?
    @State private var selectedSessionId: String?
    
    private var activeSession: PracticeSession? {
        core.view.sessions.first { $0.startTime != nil && $0.endTime == nil }
    }
    
    private var completedSessions: [PracticeSession] {
        core.view.sessions.filter { $0.endTime != nil }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                
                if let activeSession = activeSession {
                    ActiveSessionView(
                        session: activeSession,
                        core: core,
                        onSessionEnd: handleSessionEnd
                    )
                    .padding(.horizontal)
                }
                
                sessionsListView
            }
            .padding(.vertical)
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddForm) {
            SessionFormView(
                core: core,
                isPresented: $showingAddForm,
                onSessionCreated: { selectedSessionId = $0 }
            )
        }
        .sheet(isPresented: $showingReflectionForm) {
            if let session = sessionToReflect {
                SessionReflectionForm(
                    sessionId: session.id,
                    core: core,
                    isPresented: $showingReflectionForm
                )
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedSessionId != nil },
            set: { if !$0 { selectedSessionId = nil } }
        )) {
            if let sessionId = selectedSessionId {
                SessionDetailView(core: core, sessionId: sessionId)
            }
        }
    }
    
    private var headerView: some View {
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
    }
    
    private var sessionsListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent practice sessions")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            if completedSessions.isEmpty {
                Text("No sessions yet")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ForEach(completedSessions, id: \.id) { session in
                    NavigationLink(destination: SessionDetailView(core: core, sessionId: session.id)) {
                        SessionRow(session: session)
                            .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func handleSessionEnd(_ session: PracticeSession) {
        sessionToReflect = session
        showingReflectionForm = true
    }
}

struct ActiveSessionView: View {
    let session: PracticeSession
    @ObservedObject var core: Core
    let onSessionEnd: (PracticeSession) -> Void
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var navigateToDetail = false
    
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
                    
                    NavigationLink(destination: SessionDetailView(core: core, sessionId: session.id), isActive: $navigateToDetail) {
                        Button(action: goToDetails) {
                            Text("View details")
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .cornerRadius(8)
                        }
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
    
    private func goToDetails() {
        navigateToDetail = true
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

#Preview {
    SessionsView(core: Core())
}

