//
//  SessionsView.swift
//  Intrada
//
//  Created by Jon Yardley on 30/05/2025.
//

import SharedTypes
import SwiftUI

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
        case let .networkError(message):
            "Network Error: \(message)"
        case let .validationError(message):
            "Validation Error: \(message)"
        case let .coreError(message):
            "Application Error: \(message)"
        case let .unknown(message):
            "Unknown Error: \(message)"
        }
    }

    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        return .unknown(error.localizedDescription)
    }
}

/// Base view model with common state management patterns
class BaseViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: AppError?
    @Published var showingError = false

    /// Handle async operations with loading and error states
    @MainActor
    func withLoadingState<T>(_ operation: @escaping () async throws -> T) async -> T? {
        isLoading = true
        error = nil

        do {
            let result = try await operation()
            isLoading = false
            return result
        } catch {
            isLoading = false
            self.error = AppError.from(error)
            showingError = true
            return nil
        }
    }

    /// Clear current error state
    func clearError() {
        error = nil
        showingError = false
    }
}

/// View model for session-related operations
class SessionViewModel: BaseViewModel {
    private let core: Core

    init(core: Core) {
        self.core = core
        super.init()
    }

    // MARK: - Computed Properties

    @MainActor
    var sessions: [PracticeSession] {
        core.view.sessions
    }

    @MainActor
    var activeSessions: [PracticeSession] {
        sessions.filter { session in
            switch session.state {
            case .notStarted, .started, .pendingReflection:
                true
            case .ended:
                false
            }
        }
    }

    @MainActor
    var completedSessions: [PracticeSession] {
        sessions.filter { session in
            if case .ended = session.state {
                return true
            }
            return false
        }
    }

    // MARK: - Actions

    @MainActor
    func startSession(_ session: PracticeSession) {
        let startTime = Date().ISO8601Format()
        core.update(.session(.startSession(session.id, startTime)))
    }

    @MainActor
    func endSession(_ session: PracticeSession) {
        let endTime = Date().ISO8601Format()
        core.update(.session(.endSession(session.id, endTime)))
    }

    @MainActor
    func completeReflection(sessionId: String, notes: String?) {
        core.update(.session(.completeWithNotes(sessionId, notes ?? "")))
    }

    @MainActor
    func createSession(goalIds: [String], intention: String) async {
        await withLoadingState { [self] in
            let sessionId = UUID().uuidString
            let session = PracticeSession(
                id: sessionId,
                goalIds: goalIds,
                intention: intention,
                notes: nil,
                studySessions: [],
                activeStudySessionId: nil,
                state: .notStarted
            )
            core.update(.session(.createSession(session)))
        }
    }

    // MARK: - Helper Methods

    func formatDuration(from state: SessionState) -> String? {
        switch state {
        case let .ended(_, _, durationInSeconds):
            return formatDurationFromSeconds(durationInSeconds)
        case let .started(startTime), let .pendingReflection(startTime, _):
            if let duration = calculateDurationBetweenTimes(startTime: startTime, endTime: ISO8601DateFormatter().string(from: Date())) {
                return duration
            }
            return nil
        case .notStarted:
            return nil
        }
    }

    private func formatDurationFromSeconds(_ seconds: UInt32) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%02d:%02d", minutes, remainingSeconds)
        }
    }

    private func calculateDurationBetweenTimes(startTime: String, endTime: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let start = formatter.date(from: startTime),
              let end = formatter.date(from: endTime)
        else {
            return nil
        }

        let duration = end.timeIntervalSince(start)
        let seconds = UInt32(max(0, duration))
        return formatDurationFromSeconds(seconds)
    }
}

/// Reusable loading view component
struct LoadingView: View {
    let message: String

    init(_ message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
    }
}

/// Loading overlay for existing content
struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String

    init(isLoading: Bool, message: String = "Loading...") {
        self.isLoading = isLoading
        self.message = message
    }

    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message)
        }
    }
}

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

                    // Loading state
                    if viewModel.isLoading {
                        LoadingView("Loading sessions...")
                    } else {
                        // Practice Queue Section
                        if !viewModel.activeSessions.isEmpty {
                            practiceQueueSectionView
                        }

                        // Completed Sessions Section
                        if !viewModel.completedSessions.isEmpty {
                            completedSessionsSectionView
                        }

                        // Empty state when no sessions exist
                        if viewModel.sessions.isEmpty {
                            EmptyStateView(message: "No sessions yet. Tap the + button to start your first practice session.")
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.large)
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(
                LoadingOverlay(isLoading: viewModel.isLoading, message: "Loading sessions...")
            )
            .alert("Error", isPresented: $viewModel.showingError, presenting: viewModel.error) { _ in
                Button("OK") { viewModel.clearError() }
            } message: { error in
                Text(error.localizedDescription)
            }
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
        }
    }

    private var practiceQueueSectionView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            SectionHeader(title: "Practice Queue")

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
                .padding(.horizontal, Theme.Spacing.large)
            }
        }
    }

    private var completedSessionsSectionView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            SectionHeader(title: "Completed Sessions")

            ForEach(viewModel.completedSessions, id: \.id) { session in
                NavigationLink {
                    SessionDetailView(core: core, sessionId: session.id)
                } label: {
                    SessionRow(session: session, viewModel: viewModel)
                        .padding(.horizontal, Theme.Spacing.large)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func handleSessionEnd(_ session: PracticeSession) {
        sessionToReflect = session
        showingReflectionForm = true
    }
}

struct SessionRowWithActions: View {
    let session: PracticeSession
    let viewModel: SessionViewModel
    @ObservedObject var core: Core
    let onSessionEnd: (PracticeSession) -> Void
    let onTap: () -> Void

    var body: some View {
        GenericRow {
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
                                    Text(DateFormatter.formatDateAndTime(startTime))
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                            }

                            Spacer()

                            if let duration = viewModel.formatDuration(from: session.state) {
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
                viewModel.startSession(session)
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

        case .started:
            Button {
                viewModel.endSession(session)
                // Let the onSessionEnd callback handle the reflection form presentation
                onSessionEnd(session)
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

        case .pendingReflection:
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

        case .ended:
            // No action button for ended sessions
            EmptyView()
        }
    }
}

struct SessionRow: View {
    let session: PracticeSession
    let viewModel: SessionViewModel

    var body: some View {
        GenericRow {
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
                            Text(DateFormatter.formatDateAndTime(startTime))
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    if let duration = viewModel.formatDuration(from: session.state) {
                        Text(duration)
                            .badgeStyle(color: Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

// Helper function to extract start time from session state
private func extractStartTime(from state: SessionState) -> String? {
    switch state {
    case let .started(startTime):
        startTime
    case let .pendingReflection(startTime, _):
        startTime
    case let .ended(startTime, _, _):
        startTime
    case .notStarted:
        nil
    }
}

#Preview {
    SessionsView(core: Core())
}
