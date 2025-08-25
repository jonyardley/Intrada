//
//  SessionsView.swift
//  Intrada
//
//  Created by Jon Yardley on 30/05/2025.
//

import SharedTypes
import SwiftUI

struct SessionsView: View {
    @ObservedObject var core: Core
    @StateObject private var viewModel: SessionViewModel
    @State private var showingAddForm = false
    @State private var showingReflectionForm = false
    @State private var sessionToReflect: PracticeSession?
    @State private var navigationPath = NavigationPath()

    init(core: Core) {
        self.core = core
        _viewModel = StateObject(wrappedValue: SessionViewModel(core: core))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
                    ListHeader(title: "Your Sessions") {
                        showingAddForm = true
                    }

                    if !viewModel.activeSessions.isEmpty {
                        practiceQueueSectionView
                    }

                    if !viewModel.completedSessions.isEmpty {
                        completedSessionsSectionView
                    }

                    if viewModel.activeSessions.isEmpty && viewModel.completedSessions.isEmpty {
                        emptyStateView
                    }

                    Spacer(minLength: Theme.Spacing.extraLarge)
                }
                .padding(.vertical, Theme.Spacing.large)
            }
            .sheet(isPresented: $showingAddForm) {
                SessionFormView(core: core, isPresented: $showingAddForm)
            }
            .sheet(isPresented: $showingReflectionForm) {
                if let session = sessionToReflect {
                    SessionReflectionForm(sessionId: session.id, core: core, isPresented: $showingReflectionForm)
                }
            }
            .navigationDestination(for: String.self) { sessionId in
                if let session = core.view.sessions.first(where: { $0.id == sessionId }) {
                    switch session.state {
                    case .started, .pendingReflection:
                        // Keep showing ActiveSessionDetailView for both started and pendingReflection states
                        // This allows the reflection sheet to be properly presented from the active view
                        ActiveSessionDetailView(core: core, sessionId: sessionId)
                    default:
                        // For notStarted and ended states, show SessionDetailView
                        SessionDetailView(core: core, sessionId: sessionId)
                    }
                } else {
                    // Fallback for unknown session
                    SessionDetailView(core: core, sessionId: sessionId)
                }
            }
            .onAppear {
                viewModel.loadSessions()
            }
            .refreshable {
                await viewModel.refreshSessions()
            }
        }
    }

    // MARK: - Computed Properties

    private var practiceQueueSectionView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            SectionHeader(title: "Practice Queue")

            LazyVStack(spacing: Theme.Spacing.medium) {
                ForEach(viewModel.activeSessions, id: \.id) { session in
                    SessionRowWithActions(
                        session: session,
                        viewModel: viewModel,
                        core: core,
                        onSessionEnd: handleSessionEnd,
                        onTap: {
                            print("🖱️ SessionsView: Tapped on session \(session.id): \(session.intention)")
                            navigationPath.append(session.id)
                        }
                    )
                }
            }
        }
    }

    private var completedSessionsSectionView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            SectionHeader(title: "Completed Sessions")

            LazyVStack(spacing: Theme.Spacing.medium) {
                ForEach(viewModel.completedSessions, id: \.id) { session in
                    NavigationLink {
                        SessionDetailView(core: core, sessionId: session.id)
                    } label: {
                        SessionRow(session: session, viewModel: viewModel)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var emptyStateView: some View {
        EmptyStateView(message: "No sessions yet. Create your first practice session to get started.")
            .padding(.top, 60)
    }

    // MARK: - Actions

    private func handleSessionEnd(_ session: PracticeSession) {
        sessionToReflect = session
        showingReflectionForm = true
    }
}
