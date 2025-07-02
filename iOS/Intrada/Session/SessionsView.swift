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
    @State private var sessionToReflect: PracticeSessionView?
    @State private var navigationPath = NavigationPath()
    
    private var activeSession: PracticeSessionView? {
        core.view.currentSession
    }
    
    private var completedSessions: [PracticeSessionView] {
        core.view.sessions.filter { 
            $0.isEnded
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                        .onTapGesture {
                            navigationPath.append(activeSession.id)
                        }
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
                    isPresented: $showingAddForm
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
                if let session = core.view.sessions.first(where: { $0.id == sessionId }),
                   case .started(_) = session.state {
                    ActiveSessionDetailView(core: core, sessionId: sessionId)
                } else {
                    SessionDetailView(core: core, sessionId: sessionId)
                }
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
    
    private func handleSessionEnd(_ session: PracticeSessionView) {
        sessionToReflect = session
        showingReflectionForm = true
    }
}

struct ActiveSessionView: View {
    let session: PracticeSessionView
    @ObservedObject var core: Core
    let onSessionEnd: (PracticeSessionView) -> Void
    
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
                    if core.view.isSessionRunning, let elapsedTime = core.view.currentSessionElapsedTime {
                        Text(elapsedTime)
                            .font(.title3)
                            .monospacedDigit()
                            .foregroundColor(.blue)
                    } else {
                        Text("Ready?")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if core.view.isSessionRunning {
                        NavigationLink(destination: ActiveSessionDetailView(core: core, sessionId: session.id)) {
                            Text("View Session")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    } else if core.view.canStartSession {
                        Button {
                            let startTime = Date().ISO8601Format()
                            core.update(.startSession(session.id, startTime))
                        } label: {
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
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

struct SessionRow: View {
    let session: PracticeSessionView
    
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
                            .foregroundColor(.accentColor)
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

