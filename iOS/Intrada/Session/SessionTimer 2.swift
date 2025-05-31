import Foundation

class SessionTimer: ObservableObject {
    static let shared = SessionTimer()
    
    @Published var elapsedTime: TimeInterval = 0
    private var timer: Timer?
    private var startDate: Date?
    
    private init() {}
    
    func startTimer(startTime: String) {
        guard let startDate = ISO8601DateFormatter().date(from: startTime) else { return }
        self.startDate = startDate
        elapsedTime = Date().timeIntervalSince(startDate)
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.startDate else { return }
            self.elapsedTime = Date().timeIntervalSince(startDate)
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        startDate = nil
        elapsedTime = 0
    }
    
    func formatElapsedTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
} 