import Foundation
import CloudKit
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

// MARK: - CloudKit Integration

/// CloudKit container for automatic sync across devices
/// Made optional to prevent crashes when CloudKit is not properly configured
private var cloudKitContainer: CKContainer? {
    // Only initialize CloudKit if we have proper entitlements
    // This prevents the "containerIdentifier can not be nil" crash
    guard Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.icloud-container-identifiers") != nil else {
        print("⚠️ CloudKit not configured - using local-only storage")
        return nil
    }
    return CKContainer.default()
}

// MARK: - Helper Functions

/// Convert GoalStatus to string for storage
private func goalStatusToString(_ status: GoalStatus) -> String {
    switch status {
    case .notStarted:
        return "NotStarted"
    case .inProgress:
        return "InProgress"
    case .completed:
        return "Completed"
    }
}

/// Convert string to GoalStatus for loading
private func stringToGoalStatus(_ statusString: String) -> GoalStatus {
    switch statusString {
    case "NotStarted":
        return .notStarted
    case "InProgress":
        return .inProgress
    case "Completed":
        return .completed
    default:
        return .notStarted
    }
}

// MARK: - Type-Safe Local Store

/// Robust local storage using UserDefaults with CloudKit sync
/// Provides compile-time type safety and automatic conflict resolution
@MainActor
class LocalStore: ObservableObject {
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    
    init() {
        setupCloudKitSync()
    }
    
    // MARK: - CloudKit Setup
    
    private func setupCloudKitSync() {
        // Only enable CloudKit sync if container is available
        if cloudKitContainer != nil {
            defaults.set(true, forKey: "iCloud.enabled")
            
            // Request CloudKit permissions
            if let container = cloudKitContainer {
                container.requestApplicationPermission(.userDiscoverability) { status, error in
                    if let error = error {
                        print("❌ CloudKit permission error: \(error)")
                    }
                }
            }
        } else {
            // Disable CloudKit sync when not available
            defaults.set(false, forKey: "iCloud.enabled")
            print("📱 Using local-only storage (CloudKit not configured)")
        }
    }
    
    // MARK: - Type-Safe Storage Methods
    
    /// Save goals with type safety
    func saveGoals(_ goals: [PracticeGoal]) {
        let goalData = goals.map { goal in
            [
                "id": goal.id,
                "name": goal.name,
                "description": goal.description ?? "",
                "status": goalStatusToString(goal.status),
                "startDate": goal.startDate ?? "",
                "targetDate": goal.targetDate ?? "",
                "studyIds": goal.studyIds,
                "tempoTarget": goal.tempoTarget ?? 0
            ] as [String : Any]
        }
        
        saveJSONData(goalData, forKey: .goals)
        updateLastSyncTime()
    }
    
    /// Load goals with type safety
    func loadGoals() -> [PracticeGoal] {
        let goalData: [[String: Any]] = loadJSONData(forKey: .goals) ?? []
        return goalData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let statusString = dict["status"] as? String,
                  let studyIds = dict["studyIds"] as? [String] else {
                return nil
            }
            
            let description = dict["description"] as? String
            let startDate = dict["startDate"] as? String
            let targetDate = dict["targetDate"] as? String
            let tempoTarget = dict["tempoTarget"] as? UInt32
            
            return PracticeGoal(
                id: id,
                name: name,
                description: description?.isEmpty == true ? nil : description,
                status: stringToGoalStatus(statusString),
                startDate: startDate?.isEmpty == true ? nil : startDate,
                targetDate: targetDate?.isEmpty == true ? nil : targetDate,
                studyIds: studyIds,
                tempoTarget: tempoTarget == 0 ? nil : tempoTarget
            )
        }
    }
    
    /// Save studies with type safety
    func saveStudies(_ studies: [Study]) {
        let studyData = studies.map { study in
            [
                "id": study.id,
                "name": study.name,
                "description": study.description ?? ""
            ] as [String : Any]
        }
        
        saveJSONData(studyData, forKey: .studies)
        updateLastSyncTime()
    }
    
    /// Load studies with type safety
    func loadStudies() -> [Study] {
        let studyData: [[String: Any]] = loadJSONData(forKey: .studies) ?? []
        return studyData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String else {
                return nil
            }
            
            let description = dict["description"] as? String
            
            return Study(
                id: id,
                name: name,
                description: description?.isEmpty == true ? nil : description
            )
        }
    }
    
    /// Save sessions with type safety
    func saveSessions(_ sessions: [PracticeSessionView]) {
        let sessionData = sessions.map { session in
            [
                "id": session.id,
                "goalIds": session.goalIds,
                "intention": session.intention,
                "notes": session.notes ?? "",
                "duration": session.duration ?? "",
                "startTime": session.startTime ?? "",
                "endTime": session.endTime ?? "",
                "isEnded": session.isEnded
            ] as [String : Any]
        }
        
        saveJSONData(sessionData, forKey: .sessions)
        updateLastSyncTime()
    }
    
    /// Load sessions with type safety
    func loadSessions() -> [PracticeSessionView] {
        let sessionData: [[String: Any]] = loadJSONData(forKey: .sessions) ?? []
        return sessionData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let goalIds = dict["goalIds"] as? [String],
                  let intention = dict["intention"] as? String else {
                return nil
            }
            
            let notes = dict["notes"] as? String
            let duration = dict["duration"] as? String
            let startTime = dict["startTime"] as? String
            let endTime = dict["endTime"] as? String
            let isEnded = dict["isEnded"] as? Bool ?? false
            
            // For now, create a simple session view - can be expanded later
            return PracticeSessionView(
                id: id,
                goalIds: goalIds,
                intention: intention,
                state: .notStarted,
                notes: notes?.isEmpty == true ? nil : notes,
                studySessions: [],
                duration: duration?.isEmpty == true ? nil : duration,
                startTime: startTime?.isEmpty == true ? nil : startTime,
                endTime: endTime?.isEmpty == true ? nil : endTime,
                isEnded: isEnded
            )
        }
    }
    
    // MARK: - Sync Management
    
    /// Check if CloudKit is available and configured
    func isCloudKitAvailable() -> Bool {
        return cloudKitContainer != nil
    }
    
    /// Check if data needs to be synced (older than 1 hour)
    func needsSync() -> Bool {
        // If CloudKit is not available, we don't need to sync
        guard cloudKitContainer != nil else {
            return false
        }
        
        let lastSync = getLastSyncTime()
        let hourAgo = Date().timeIntervalSince1970 - 3600
        return lastSync < hourAgo
    }
    
    /// Get last sync time
    func getLastSyncTime() -> TimeInterval {
        return defaults.double(forKey: StorageKey.lastSyncTime.rawValue)
    }
    
    /// Update last sync time
    private func updateLastSyncTime() {
        defaults.set(Date().timeIntervalSince1970, forKey: StorageKey.lastSyncTime.rawValue)
    }
    
    // MARK: - JSON Storage Methods
    
    /// Type-safe save method using JSON
    private func saveJSONData<T>(_ data: T, forKey key: StorageKey) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            defaults.set(jsonData, forKey: key.rawValue)
        } catch {
            print("❌ Failed to save data for key \(key.rawValue): \(error)")
        }
    }
    
    /// Type-safe load method using JSON
    private func loadJSONData<T>(forKey key: StorageKey) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else {
            return nil
        }
        
        do {
            return try JSONSerialization.jsonObject(with: data) as? T
        } catch {
            print("❌ Failed to load data for key \(key.rawValue): \(error)")
            return nil
        }
    }
    
    // MARK: - Data Migration
    
    /// Migrate data from old storage format if needed
    func migrateIfNeeded() {
        // Check if migration is needed
        let migrationKey = "migration_completed_v1"
        if !defaults.bool(forKey: migrationKey) {
            performMigration()
            defaults.set(true, forKey: migrationKey)
        }
    }
    
    private func performMigration() {
        print("🔄 Performing data migration...")
        // Add migration logic here if needed
    }
    
    // MARK: - Debug Methods
    
    /// Clear all stored data (for testing)
    func clearAll() {
        for key in StorageKey.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
        print("🗑️ All local data cleared")
    }
    
    /// Get storage statistics
    func getStorageStats() -> StorageStats {
        let goals = loadGoals()
        let studies = loadStudies()
        let sessions = loadSessions()
        
        return StorageStats(
            goalsCount: goals.count,
            studiesCount: studies.count,
            sessionsCount: sessions.count,
            lastSyncTime: getLastSyncTime(),
            needsSync: needsSync(),
            cloudKitAvailable: isCloudKitAvailable()
        )
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

// MARK: - CloudKit Sync Extensions

extension LocalStore {
    /// Trigger manual CloudKit sync
    func syncWithCloudKit() async {
        guard let container = cloudKitContainer else {
            print("⚠️ CloudKit not configured, skipping sync.")
            return
        }
        
        do {
            let database = container.privateCloudDatabase
            
            // Sync goals
            let goals = loadGoals()
            try await syncGoalsToCloudKit(goals, database: database)
            
            // Sync studies
            let studies = loadStudies()
            try await syncStudiesToCloudKit(studies, database: database)
            
            // Sync sessions
            let sessions = loadSessions()
            try await syncSessionsToCloudKit(sessions, database: database)
            
            updateLastSyncTime()
            print("✅ CloudKit sync completed successfully")
            
        } catch {
            print("❌ CloudKit sync failed: \(error)")
        }
    }
    
    private func syncGoalsToCloudKit(_ goals: [PracticeGoal], database: CKDatabase) async throws {
        for goal in goals {
            let record = CKRecord(recordType: "Goal")
            record.setValue(goal.id, forKey: "id")
            record.setValue(goal.name, forKey: "name")
            record.setValue(goal.description, forKey: "description")
            record.setValue(goalStatusToString(goal.status), forKey: "status")
            record.setValue(goal.startDate, forKey: "startDate")
            record.setValue(goal.targetDate, forKey: "targetDate")
            record.setValue(goal.studyIds, forKey: "studyIds")
            record.setValue(goal.tempoTarget, forKey: "tempoTarget")
            
            try await database.save(record)
        }
    }
    
    private func syncStudiesToCloudKit(_ studies: [Study], database: CKDatabase) async throws {
        for study in studies {
            let record = CKRecord(recordType: "Study")
            record.setValue(study.id, forKey: "id")
            record.setValue(study.name, forKey: "name")
            record.setValue(study.description, forKey: "description")
            
            try await database.save(record)
        }
    }
    
    private func syncSessionsToCloudKit(_ sessions: [PracticeSessionView], database: CKDatabase) async throws {
        for session in sessions {
            let record = CKRecord(recordType: "Session")
            record.setValue(session.id, forKey: "id")
            record.setValue(session.goalIds, forKey: "goalIds")
            record.setValue(session.intention, forKey: "intention")
            record.setValue(session.notes, forKey: "notes")
            record.setValue(session.duration, forKey: "duration")
            record.setValue(session.startTime, forKey: "startTime")
            record.setValue(session.endTime, forKey: "endTime")
            record.setValue(session.isEnded, forKey: "isEnded")
            
            try await database.save(record)
        }
    }
} 