import Foundation
import SharedTypes

// MARK: - Appwrite Service

class AppwriteService {
    private let config = ConfigurationManager.shared
    
    // MARK: - Configuration
    
    private var endpoint: String { config.appwriteEndpoint }
    private var projectId: String { config.appwriteProjectId }
    private var databaseId: String { config.appwriteDatabaseId }
    private var collectionId: String { config.appwriteCollectionId }
    private var apiKey: String { config.appwriteApiKey }
    
    // MARK: - Goals Operations
    
    func fetchGoals() async throws -> [PracticeGoal] {
        let documents: AppwriteDocumentsResponse = try await performRequest(
            path: "/documents",
            method: "GET"
        )
        
        return documents.documents.map { $0.toPracticeGoal() }
    }
    
    func createGoal(_ goal: PracticeGoal) async throws -> PracticeGoal {
        let documentData: [String: Any] = [
            "documentId": goal.id,
            "data": goal.toAppwriteData()
        ]
        
        let document: AppwriteDocument = try await performRequest(
            path: "/documents",
            method: "POST",
            body: documentData
        )
        
        return document.toPracticeGoal()
    }
    
    func updateGoal(_ goal: PracticeGoal) async throws -> PracticeGoal {
        let documentData: [String: Any] = [
            "data": goal.toAppwriteData()
        ]
        
        let document: AppwriteDocument = try await performRequest(
            path: "/documents/\(goal.id)",
            method: "PATCH",
            body: documentData
        )
        
        return document.toPracticeGoal()
    }
    
    func deleteGoal(_ goalId: String) async throws {
        _ = try await performRequest(
            path: "/documents/\(goalId)",
            method: "DELETE"
        ) as EmptyResponse
    }
}

// MARK: - Private Helpers

private extension AppwriteService {
    func performRequest<T: Codable>(
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> T {
        let urlString = "\(endpoint)/databases/\(databaseId)/collections/\(collectionId)\(path)"
        guard let url = URL(string: urlString) else {
            throw AppwriteError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(projectId, forHTTPHeaderField: "X-Appwrite-Project")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppwriteError.invalidResponse
        }
        
        let expectedStatusCodes: [Int] = method == "DELETE" ? [204] : [200, 201]
        guard expectedStatusCodes.contains(httpResponse.statusCode) else {
            throw AppwriteError.httpError(httpResponse.statusCode)
        }
        
        // For DELETE operations, we don't need to decode response
        if method == "DELETE" {
            if T.self == Void.self {
                return () as! T
            } else if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            } else {
                throw AppwriteError.invalidResponseType
            }
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Data Transformations

private extension PracticeGoal {
    func toAppwriteData() -> [String: Any] {
        return [
            "name": name,
            "description": description ?? "",
            "status": statusToString(status),
            "startDate": startDate ?? "",
            "targetDate": targetDate ?? "",
            "exerciseIds": exerciseIds,
            "tempoTarget": tempoTarget.map { Int32($0) } ?? 0
        ]
    }
}

private extension AppwriteDocument {
    func toPracticeGoal() -> PracticeGoal {
        return PracticeGoal(
            id: id ?? "",
            name: name ?? "",
            description: description,
            status: stringToStatus(status ?? "NotStarted"),
            startDate: startDate,
            targetDate: targetDate,
            exerciseIds: exerciseIds ?? [],
            tempoTarget: tempoTarget.map { UInt32($0) }
        )
    }
}

// MARK: - Status Conversion

private func statusToString(_ status: GoalStatus) -> String {
    switch status {
    case .notStarted:
        return "NotStarted"
    case .inProgress:
        return "InProgress"
    case .completed:
        return "Completed"
    }
}

private func stringToStatus(_ statusString: String) -> GoalStatus {
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

// MARK: - Response Models

struct AppwriteDocumentsResponse: Codable {
    let documents: [AppwriteDocument]
    let total: Int
}

struct AppwriteDocument: Codable {
    let id: String?
    let createdAt: String?
    let updatedAt: String?
    let name: String?
    let description: String?
    let status: String?
    let startDate: String?
    let targetDate: String?
    let exerciseIds: [String]?
    let tempoTarget: Int32?
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case createdAt = "$createdAt"
        case updatedAt = "$updatedAt"
        case name, description, status, startDate, targetDate, exerciseIds, tempoTarget
    }
}

struct EmptyResponse: Codable {}

// MARK: - Errors

enum AppwriteError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidResponseType
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .invalidResponseType:
            return "Invalid response type"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
} 