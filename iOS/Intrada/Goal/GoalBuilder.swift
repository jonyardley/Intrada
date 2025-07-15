import Foundation
import SharedTypes

// MARK: - Goal Builder Errors

public enum GoalBuilderError: Error, LocalizedError {
    case missingName
    case invalidTempo(String)
    case invalidDate(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingName:
            return "Goal name is required"
        case .invalidTempo(let tempo):
            return "Invalid tempo: \(tempo). Must be between 1 and 300 BPM"
        case .invalidDate(let date):
            return "Invalid date: \(date). Must be in yyyy-MM-dd format"
        }
    }
}

// MARK: - Goal Builder

public struct GoalBuilder {
    private let id: String
    private var name: String?
    private var description: String?
    private var status: GoalStatus
    private var startDate: String?
    private var targetDate: String?
    private var studyIds: [String]
    private var tempoTarget: UInt32?
    
    public init(id: String = UUID().uuidString) {
        self.id = id
        self.status = .notStarted
        self.studyIds = []
    }
    
    public init(from goal: PracticeGoal) {
        self.id = goal.id
        self.name = goal.name
        self.description = goal.description
        self.status = goal.status
        self.startDate = goal.startDate
        self.targetDate = goal.targetDate
        self.studyIds = goal.studyIds
        self.tempoTarget = goal.tempoTarget
    }
    
    public func name(_ value: String) -> Self {
        var builder = self
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        builder.name = trimmed.isEmpty ? nil : trimmed
        return builder
    }
    
    public func description(_ value: String?) -> Self {
        var builder = self
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        builder.description = trimmed?.isEmpty == true ? nil : trimmed
        return builder
    }
    
    public func status(_ value: GoalStatus) -> Self {
        var builder = self
        builder.status = value
        return builder
    }
    
    public func targetDate(_ date: Date?) -> Self {
        var builder = self
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            builder.targetDate = formatter.string(from: date)
        } else {
            builder.targetDate = nil
        }
        return builder
    }
    
    public func targetDate(_ dateString: String?) -> Self {
        var builder = self
        builder.targetDate = dateString
        return builder
    }
    
    public func tempoTarget(_ tempo: UInt32?) -> Self {
        var builder = self
        builder.tempoTarget = tempo
        return builder
    }
    
    public func tempoTarget(_ tempoString: String) -> Self {
        var builder = self
        if let tempo = UInt32(tempoString) {
            builder.tempoTarget = tempo
        }
        return builder
    }
    
    public func studyIds(_ ids: [String]) -> Self {
        var builder = self
        builder.studyIds = ids
        return builder
    }
    
    public func build() -> Result<PracticeGoal, GoalBuilderError> {
        guard let name = name, !name.isEmpty else {
            return .failure(.missingName)
        }
        
        if let tempo = tempoTarget, tempo == 0 || tempo > 300 {
            return .failure(.invalidTempo(String(tempo)))
        }
        
        if let dateString = targetDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard formatter.date(from: dateString) != nil else {
                return .failure(.invalidDate(dateString))
            }
        }
        
        return .success(PracticeGoal(
            id: id,
            name: name,
            description: description,
            status: status,
            startDate: startDate,
            targetDate: targetDate,
            studyIds: studyIds,
            tempoTarget: tempoTarget
        ))
    }
}