//
//  SessionViewModel.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SharedTypes
import SwiftUI

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
