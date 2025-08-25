import Foundation
import SharedTypes

// MARK: - Type-Safe Storage Keys

/// Compile-time type-safe storage keys to prevent typos and ensure consistency
enum StorageKey: String, CaseIterable {
    case goals = "cached_goals"
    case studies = "cached_studies"
    case sessions = "cached_sessions"
    case lastSyncTime = "last_sync_time"
    case pendingChanges = "pending_changes"
    case userPreferences = "user_preferences"
}

// MARK: - Helper Functions

/// Convert GoalStatus to string for storage
func goalStatusToString(_ status: GoalStatus) -> String {
    switch status {
    case .notStarted:
        "NotStarted"
    case .inProgress:
        "InProgress"
    case .completed:
        "Completed"
    }
}

/// Convert string to GoalStatus for loading
func stringToGoalStatus(_ statusString: String) -> GoalStatus {
    switch statusString {
    case "NotStarted":
        .notStarted
    case "InProgress":
        .inProgress
    case "Completed":
        .completed
    default:
        .notStarted
    }
}

// MARK: - Storage Statistics

struct StorageStats {
    let goalsCount: Int
    let studiesCount: Int
    let sessionsCount: Int
    let lastSyncTime: TimeInterval
    let needsSync: Bool
    let cloudKitAvailable: Bool

    var lastSyncDate: Date {
        Date(timeIntervalSince1970: lastSyncTime)
    }

    var formattedLastSync: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: lastSyncDate)
    }
}
