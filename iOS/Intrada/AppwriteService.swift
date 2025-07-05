import Foundation
import SharedTypes
import Appwrite
import JSONCodable

// MARK: - Appwrite Service

class AppwriteService {
    private let config = ConfigurationManager.shared
    private let client: Client
    private let databases: Databases
    
    // MARK: - Initialization
    
    init() {
        // Initialize Appwrite client
        self.client = Client()
            .setEndpoint(config.appwriteEndpoint)
            .setProject(config.appwriteProjectId)
        
        self.databases = Databases(client)
    }
    
    // MARK: - Configuration Properties
    
    private var databaseId: String { config.appwriteDatabaseId }
    
    // Collection IDs - these match the database schema
    private var goalsCollectionId: String { "goals" }
    private var studiesCollectionId: String { "studies" }
    private var sessionsCollectionId: String { "sessions" }
    private var studySessionsCollectionId: String { "study_sessions" }
    
    // MARK: - Goals Operations
    
    func fetchGoals() async throws -> [PracticeGoal] {
        let documents = try await databases.listDocuments(
            databaseId: databaseId,
            collectionId: goalsCollectionId
        )
        
        return documents.documents.compactMap { document in
            try? documentToPracticeGoal(document)
        }
    }
    
    func createGoal(_ goal: PracticeGoal) async throws -> PracticeGoal {
        let data = practiceGoalToData(goal)
        
        let document = try await databases.createDocument(
            databaseId: databaseId,
            collectionId: goalsCollectionId,
            documentId: goal.id,
            data: data
        )
        
        return try documentToPracticeGoal(document)
    }
    
    func updateGoal(_ goal: PracticeGoal) async throws -> PracticeGoal {
        let data = practiceGoalToData(goal)
        
        let document = try await databases.updateDocument(
            databaseId: databaseId,
            collectionId: goalsCollectionId,
            documentId: goal.id,
            data: data
        )
        
        return try documentToPracticeGoal(document)
    }
    
    func deleteGoal(_ goalId: String) async throws {
        _ = try await databases.deleteDocument(
            databaseId: databaseId,
            collectionId: goalsCollectionId,
            documentId: goalId
        )
    }
}

// MARK: - Data Transformations

private extension AppwriteService {
    func practiceGoalToData(_ goal: PracticeGoal) -> [String: Any] {
        var data: [String: Any] = [
            "name": goal.name,
            "description": goal.description ?? "",
            "status": goal.status.rawValue,
            "studyIds": goal.studyIds
        ]
        
        if let startDate = goal.startDate {
            data["startDate"] = startDate
        }
        
        if let targetDate = goal.targetDate {
            data["targetDate"] = targetDate
        }
        
        if let tempoTarget = goal.tempoTarget {
            data["tempoTarget"] = Int32(tempoTarget)
        }
        
        return data
    }
    
    func documentToPracticeGoal(_ document: Document<[String: AnyCodable]>) throws -> PracticeGoal {
        let id = document.id
        
        let data = document.data
        
        guard let name = data["name"]?.value as? String else {
            throw AppwriteError.invalidDocument
        }
        
        let description = data["description"]?.value as? String
        let statusString = data["status"]?.value as? String ?? "NotStarted"
        let startDate = data["startDate"]?.value as? String
        let targetDate = data["targetDate"]?.value as? String
        let studyIds = data["studyIds"]?.value as? [String] ?? []
        let tempoTarget = data["tempoTarget"]?.value as? Int32
        
        return PracticeGoal(
            id: id,
            name: name,
            description: description?.isEmpty == false ? description : nil,
            status: GoalStatus(rawValue: statusString) ?? .notStarted,
            startDate: startDate?.isEmpty == false ? startDate : nil,
            targetDate: targetDate?.isEmpty == false ? targetDate : nil,
            studyIds: studyIds,
            tempoTarget: tempoTarget.map { UInt32($0) }
        )
    }
}

// MARK: - GoalStatus Extension

extension GoalStatus: @retroactive RawRepresentable, @retroactive CaseIterable {
    public typealias RawValue = String
    
    public var rawValue: String {
        switch self {
        case .notStarted: return "NotStarted"
        case .inProgress: return "InProgress"
        case .completed: return "Completed"
        }
    }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "NotStarted": self = .notStarted
        case "InProgress": self = .inProgress
        case "Completed": self = .completed
        default: return nil
        }
    }
    
    public static var allCases: [GoalStatus] {
        return [.notStarted, .inProgress, .completed]
    }
}

// MARK: - Errors

enum AppwriteError: Error, LocalizedError {
    case invalidDocument
    case conversionError
    
    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            return "Invalid document structure"
        case .conversionError:
            return "Failed to convert data"
        }
    }
} 