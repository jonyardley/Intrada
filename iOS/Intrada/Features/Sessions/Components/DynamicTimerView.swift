import SharedTypes
import SwiftUI

struct DynamicTimerView: View {
    let session: PracticeSession
    let fontSize: Font
    let textColor: Color

    @State private var currentTime = Date()
    @State private var timer: Timer?

    init(session: PracticeSession, fontSize: Font = .title3, textColor: Color = .blue) {
        self.session = session
        self.fontSize = fontSize
        self.textColor = textColor
    }

    var body: some View {
        Text(calculateElapsedTime())
            .font(fontSize)
            .monospacedDigit()
            .foregroundColor(textColor)
            .onAppear {
                // Force immediate update when view appears
                currentTime = Date()
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
    }

    private func startTimer() {
        // Immediately update the current time to ensure fresh calculation
        currentTime = Date()

        // Update every second to refresh the elapsed time
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func calculateElapsedTime() -> String {
        // Extract start time from session state
        let startTimeString: String? = switch session.state {
        case let .started(startTime):
            startTime
        case let .pendingReflection(startTime, _):
            startTime
        case let .ended(startTime, _, _):
            startTime
        case .notStarted:
            nil
        }

        guard let startTimeString else {
            return "00:00:00"
        }

        let formatter = ISO8601DateFormatter()
        guard let startTime = formatter.date(from: startTimeString) else {
            return "00:00:00"
        }

        let elapsed = currentTime.timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
