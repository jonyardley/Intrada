import CloudKit
import Foundation
import SharedTypes

// MARK: - CloudKit Integration

/// CloudKit container for automatic sync across devices
/// Made optional to prevent crashes when CloudKit is not properly configured
var cloudKitContainer: CKContainer? {
    // Only initialize CloudKit if we have proper entitlements
    // This prevents the "containerIdentifier can not be nil" crash
    guard Bundle.main.object(forInfoDictionaryKey: "com.apple.developer.icloud-container-identifiers") != nil else {
        print("⚠️ CloudKit not configured - using local-only storage")
        return nil
    }
    return CKContainer.default()
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

    private func syncSessionsToCloudKit(_ sessions: [PracticeSession], database: CKDatabase) async throws {
        for session in sessions {
            let record = CKRecord(recordType: "Session")
            record.setValue(session.id, forKey: "id")
            record.setValue(session.goalIds, forKey: "goalIds")
            record.setValue(session.intention, forKey: "intention")
            record.setValue(session.notes, forKey: "notes")
            record.setValue(extractDurationInSeconds(from: session.state), forKey: "duration")
            record.setValue(extractStartTime(from: session.state), forKey: "startTime")
            record.setValue(extractEndTime(from: session.state), forKey: "endTime")
            record.setValue(isSessionEnded(session.state), forKey: "isEnded")

            try await database.save(record)
        }
    }
}
