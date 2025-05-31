import Foundation

class SessionTimer: ObservableObject {
    static let shared = SessionTimer()
    
    @Published var elapsedTime: TimeInterval = 0
    private var timer: Timer?
    private var startDate: Date?
    private var isRunning: Bool = false
    
    private init() {}
    
    func startTimer(startTime: String) {
        // Only start if not already running
        guard !isRunning else { return }
        
        guard let startDate = ISO8601DateFormatter().date(from: startTime) else { return }
        self.startDate = startDate
        elapsedTime = Date().timeIntervalSince(startDate)
        isRunning = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self, let startDate = self.startDate else { return }
                self.elapsedTime = Date().timeIntervalSince(startDate)
            }
            RunLoop.current.add(self.timer!, forMode: .common)
        }
    }
    
    func stopTimer() {
        // Only stop if actually running
        guard isRunning else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
            self?.startDate = nil
            self?.elapsedTime = 0
            self?.isRunning = false
        }
    }
    
    func formatElapsedTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
} 