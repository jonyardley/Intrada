import Foundation
import SharedTypes

// MARK: - Session State Helper Functions

func extractStartTime(from state: SessionState) -> String? {
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

func extractEndTime(from state: SessionState) -> String? {
    switch state {
    case let .pendingReflection(_, endTime):
        endTime
    case let .ended(_, endTime, _):
        endTime
    case .started, .notStarted:
        nil
    }
}

func isSessionEnded(_ state: SessionState) -> Bool {
    switch state {
    case .ended:
        true
    case .notStarted, .started, .pendingReflection:
        false
    }
}

func extractDurationInSeconds(from state: SessionState) -> UInt32? {
    switch state {
    case let .ended(_, _, durationInSeconds):
        durationInSeconds
    case let .pendingReflection(startTime, endTime):
        calculateDurationInSecondsBetweenTimes(startTime: startTime, endTime: endTime)
    case .notStarted, .started:
        nil
    }
}

private func calculateDurationInSecondsBetweenTimes(startTime: String, endTime: String) -> UInt32? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    guard let start = formatter.date(from: startTime),
          let end = formatter.date(from: endTime)
    else {
        return nil
    }

    let duration = end.timeIntervalSince(start)
    return UInt32(max(0, duration))
}
