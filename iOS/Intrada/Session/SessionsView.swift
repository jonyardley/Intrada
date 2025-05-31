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
    
    private var activeSession: PracticeSession? {
        core.view.sessions.first { $0.startTime != nil && $0.endTime == nil }
    }
    
    private var completedSessions: [PracticeSession] {
        core.view.sessions.filter { $0.endTime != nil }
    }
    
    var body: some View {
        NavigationStack {
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
                    onSessionCreated: { sessionId in
                        core.update(.startSession(sessionId, Date().ISO8601Format()))
                    }
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
            .navigationDestination(for: String.self) { sessionId in
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
                .padding(.top)
            
            if completedSessions.isEmpty {
                Text("No sessions yet")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ForEach(completedSessions, id: \.id) { session in
                    NavigationLink {
                        SessionDetailView(core: core, sessionId: session.id)
                    } label: {
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
    @StateObject private var sessionTimer = SessionTimer.shared
    
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
                    if session.startTime != nil {
                        Text(sessionTimer.formatElapsedTime(sessionTimer.elapsedTime))
                            .font(.title3)
                            .monospacedDigit()
                            .foregroundColor(.blue)
                        
                        NavigationLink(destination: SessionDetailView(core: core, sessionId: session.id)) {
                            Text("View Session")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    } else {
                        Text("Ready?")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if session.startTime == nil {
                        NavigationLink(destination: SessionDetailView(core: core, sessionId: session.id)) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                Text("Start Session")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            let startTime = Date().ISO8601Format()
                            core.update(.startSession(session.id, startTime))
                            sessionTimer.startTimer(startTime: startTime)
                        })
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
        .onAppear {
            if let startTime = session.startTime {
                sessionTimer.startTimer(startTime: startTime)
            }
        }
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

