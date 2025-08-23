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
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.extraLarge) {
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
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddForm = true }) {
                        Image(systemName: "plus")
                    }
                }
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

// MARK: - Temporary inline ViewModels and Components (to be moved to separate files)

/// Application-specific error types
enum AppError: LocalizedError, Identifiable {
    case networkError(String)
    case validationError(String)
    case coreError(String)
    case unknown(String)

    var id: String {
        switch self {
        case let .networkError(msg): "network_\(msg.hashValue)"
        case let .validationError(msg): "validation_\(msg.hashValue)"
        case let .coreError(msg): "core_\(msg.hashValue)"
        case let .unknown(msg): "unknown_\(msg.hashValue)"
        }
    }

    var errorDescription: String? {
        switch self {
        case let .networkError(message): "Network Error: \(message)"
        case let .validationError(message): "Validation Error: \(message)"
        case let .coreError(message): "Core Error: \(message)"
        case let .unknown(message): "Unknown Error: \(message)"
        }
    }
}

/// Session-specific view model for managing session state
class SessionViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: AppError?
    @Published var activeSessions: [PracticeSession] = []
    @Published var completedSessions: [PracticeSession] = []

    private let core: Core

    init(core: Core) {
        self.core = core
    }

    @MainActor
    func loadSessions() {
        updateSessionLists()
    }

    @MainActor
    func refreshSessions() async {
        isLoading = true
        error = nil

        do {
            // Simulate network refresh with a small delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            updateSessionLists()
        } catch {
            self.error = .unknown("Failed to refresh sessions")
        }

        isLoading = false
    }

    @MainActor
    private func updateSessionLists() {
        let allSessions = core.view.sessions

        activeSessions = allSessions.filter { session in
            switch session.state {
            case .started, .pendingReflection:
                true
            default:
                false
            }
        }

        completedSessions = allSessions.filter { session in
            if case .ended = session.state {
                return true
            }
            return false
        }
    }
}

/// Reusable loading view component
struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primary))

            Text(message)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.backgroundSecondary)
    }
}

/// Loading overlay for existing content
struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String

    var body: some View {
        ZStack {
            if isLoading {
                Color.clear
                    .background(.ultraThinMaterial)

                VStack(spacing: Theme.Spacing.medium) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(message)
            }
        }
    }
}

// MARK: - Session Row Components

struct SessionRowWithActions: View {
    let session: PracticeSession
    let viewModel: SessionViewModel
    let core: Core
    let onSessionEnd: (PracticeSession) -> Void
    let onTap: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                HStack {
                    // Tappable content area
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text(session.intention)
                            .font(Theme.Typography.headline)

                        if let notes = session.notes, !notes.isEmpty {
                            Text(notes)
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }

                        HStack {
                            if let startTime = extractStartTime(from: session.state) {
                                HStack(spacing: Theme.Spacing.extraSmall) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(Theme.Colors.primary)
                                    Text(DateFormatter.formatDate(startTime))
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }

                            Spacer()

                            SessionStateView(state: session.state)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap()
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: Theme.Spacing.small) {
                        if case .started = session.state {
                            Button("End") {
                                onSessionEnd(session)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: PracticeSession
    let viewModel: SessionViewModel

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text(session.intention)
                    .font(Theme.Typography.headline)

                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                HStack {
                    if let startTime = extractStartTime(from: session.state) {
                        HStack(spacing: Theme.Spacing.extraSmall) {
                            Image(systemName: "calendar")
                                .foregroundColor(Theme.Colors.primary)
                            Text(DateFormatter.formatDate(startTime))
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    SessionStateView(state: session.state)
                }
            }
        }
    }
}

// MARK: - Helper Functions

private func extractStartTime(from state: SessionState) -> String? {
    switch state {
    case let .started(startTime), let .pendingReflection(startTime, _), let .ended(startTime, _, _):
        return startTime
    case .notStarted:
        return nil
    }
}

extension DateFormatter {
    static func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Session State View

private struct SessionStateView: View {
    let state: SessionState

    var body: some View {
        HStack(spacing: Theme.Spacing.extraSmall) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            Text(stateText)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }

    private var stateColor: Color {
        switch state {
        case .notStarted:
            return Color.gray
        case .started:
            return Color.green
        case .pendingReflection:
            return Color.orange
        case .ended:
            return Color.blue
        }
    }

    private var stateText: String {
        switch state {
        case .notStarted:
            return "Not Started"
        case .started:
            return "In Progress"
        case .pendingReflection:
            return "Pending Reflection"
        case .ended:
            return "Completed"
        }
    }
}
