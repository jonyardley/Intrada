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
    
    private var practiceQueueSessions: [PracticeSessionView] {
        core.view.sessions.filter { !$0.isEnded }
    }
    
    private var completedSessions: [PracticeSessionView] {
        core.view.sessions.filter { $0.isEnded }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ListHeader(title: "Your Sessions") {
                        showingAddForm = true
                    }
                    
                    // Practice Queue Section
                    if !practiceQueueSessions.isEmpty {
                        practiceQueueSectionView
                    }
                    
                    // Completed Sessions Section
                    if !completedSessions.isEmpty {
                        completedSessionsSectionView
                    }
                    
                    // Empty state when no sessions exist
                    if core.view.sessions.isEmpty {
                        EmptyStateView(message: "No sessions yet")
                    }
                }
                .padding(.vertical, Theme.Spacing.lg)
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddForm) {
                SessionFormView(
                    core: core,
                    isPresented: $showingAddForm,
                    onSessionCreated: { sessionId in
                        navigationPath.append(sessionId)
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
                if let session = core.view.sessions.first(where: { $0.id == sessionId }),
                   case .started(_) = session.state {
                    ActiveSessionDetailView(core: core, sessionId: sessionId)
                } else if let session = core.view.sessions.first(where: { $0.id == sessionId }),
                         case .pendingReflection(_, _) = session.state {
                    // For PendingReflection, show the reflection form immediately
                    SessionReflectionForm(
                        sessionId: sessionId,
                        core: core,
                        isPresented: .constant(true)
                    )
                } else {
                    SessionDetailView(core: core, sessionId: sessionId)
                }
            }
        }
    }
    
    private var practiceQueueSectionView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Practice Queue")
            
            ForEach(practiceQueueSessions, id: \.id) { session in
                SessionRowWithActions(
                    session: session,
                    core: core,
                    onSessionEnd: handleSessionEnd,
                    onTap: {
                        print("🖱️ SessionsView: Tapped on session \(session.id): \(session.intention)")
                        navigationPath.append(session.id)
                    }
                )
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }
    
    private var completedSessionsSectionView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Completed Sessions")
            
            ForEach(completedSessions, id: \.id) { session in
                NavigationLink {
                    SessionDetailView(core: core, sessionId: session.id)
                } label: {
                    SessionRow(session: session)
                        .padding(.horizontal, Theme.Spacing.lg)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func handleSessionEnd(_ session: PracticeSessionView) {
        sessionToReflect = session
        showingReflectionForm = true
    }
}

struct SessionRowWithActions: View {
    let session: PracticeSessionView
    @ObservedObject var core: Core
    let onSessionEnd: (PracticeSessionView) -> Void
    let onTap: () -> Void
    
    var body: some View {
        GenericRow {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    // Tappable content area
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(session.intention)
                            .font(Theme.Typography.headline)
                        
                        if let notes = session.notes, !notes.isEmpty {
                            Text(notes)
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        
                        HStack {
                            if let startTime = session.startTime {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(Theme.Colors.primary)
                                    Text(DateFormatter.formatDateAndTime(startTime))
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            if let duration = session.duration {
                                Text(duration)
                                    .badgeStyle(color: Theme.Colors.textSecondary)
                            }
                        }
                    }
                    .onTapGesture {
                        onTap()
                    }
                    
                    Spacer()
                    
                    // State transition button (not affected by tap gesture)
                    stateTransitionButton
                }
            }
        }
    }
    
    @ViewBuilder
    private var stateTransitionButton: some View {
        switch session.state {
        case .notStarted:
            Button {
                let startTime = Date().ISO8601Format()
                print("▶️ SessionsView: Starting session \(session.id) at \(startTime)")
                print("📊 Current session state before: \(session.state)")
                
                // Use local event for immediate UI update, then optimistic sync
                core.update(.session(.startSession(session.id, startTime)))
                print("📊 Session count after update: \(core.view.sessions.count)")
                
                // Immediately navigate to active session
                onTap()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                    Text("Start")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .cornerRadius(6)
            }
            
        case .started(_):
            Button {
                let endTime = Date().ISO8601Format()
                core.update(.session(.endSession(session.id, endTime)))
                // Don't call onSessionEnd here - let the UI handle PendingReflection state
                onTap() // Navigate to show reflection form
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                    Text("End")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red)
                .cornerRadius(6)
            }
            
        case .pendingReflection(_, _):
            Button {
                // Navigate to reflection form
                onTap()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                    Text("Reflect")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange)
                .cornerRadius(6)
            }
            
        case .ended(_, _):
            // No action button for ended sessions
            EmptyView()
        }
    }
}

struct SessionRow: View {
    let session: PracticeSessionView
    
    var body: some View {
        GenericRow {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(session.intention)
                    .font(Theme.Typography.headline)
                
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                HStack {
                    if let startTime = session.startTime {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "calendar")
                                .foregroundColor(Theme.Colors.primary)
                            Text(DateFormatter.formatDateAndTime(startTime))
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    if let duration = session.duration {
                        Text(duration)
                            .badgeStyle(color: Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}



#Preview {
    SessionsView(core: Core())
}

