import Foundation
import Shared
import SharedTypes

var isPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

fileprivate class EffectHandler: CruxShell, @unchecked Sendable {
    public var handler: ((Data) -> Void)?

    func processEffects(_ bytes: Data) {
        // The handler is set straight after initialising the EffectHandler
        // it should never be nil
        handler?(bytes)
    }
}

@MainActor
class Core: ObservableObject {
    @Published var view: ViewModel

    private var handler: EffectHandler
    private var core: CoreFfi
    private var dataStore: LocalStore
    private var syncTimer: Timer?

    init() {
        print("🚀 Core init started")
        self.handler = EffectHandler()
        self.core = CoreFfi(handler)
        self.dataStore = LocalStore()
        
        // Initialize view with default state
        let bytes = [UInt8](core.view())
        if bytes.isEmpty || bytes.count < 4 {
            if !isPreview {
                print("Warning: Core returned empty or too-small view data, using default ViewModel")
            }
            self.view = Self.createDefaultViewModel()
        } else {
            do {
                self.view = try .bincodeDeserialize(input: bytes)
            } catch {
                if !isPreview {
                    print("Warning: Failed to deserialize existing data, starting with fresh state: \(error)")
                }
                self.view = Self.createDefaultViewModel()
            }
        }

        // the handler assignment needs to be deferred, otherwise we create a circular
        // reference between handler and self, before self is done initializing
        handler.handler = { bytes in
            do {
                let requests: [Request] = try .bincodeDeserialize(input: [UInt8](bytes))
                for request in requests {
                    self.processEffect(request)
                }
            } catch {
                if !isPreview {
                    print("Warning: Failed to deserialize requests: \(error)")
                }
            }
        }
        
        // Load from local store after handler is set up
        loadFromStore()
        
        // Start background sync if needed
        startSyncTimer()
        
        // Fetch from server if needed (non-blocking)
        Task {
            await self.syncWithServerIfNeeded()
        }
    }
    
    private static func createDefaultViewModel() -> ViewModel {
        ViewModel(
            goals: [],
            studies: [],
            sessions: [],
            currentSession: nil,
            hasActiveSession: false,
            canStartSession: false,
            canEndSession: false,
            isSessionRunning: false,
            isSessionEnded: false,
            currentSessionElapsedTime: nil,
            lastError: nil
        )
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - Local Store Integration
    
    private func loadFromStore() {
        guard !isPreview else { return }
        
        print("📱 Loading data from LocalStore...")
        
        let goals = dataStore.loadGoals()
        let studies = dataStore.loadStudies()
        let sessions = dataStore.loadSessions()
        
        print("📱 LocalStore data: \(goals.count) goals, \(studies.count) studies, \(sessions.count) sessions")
        
        if !goals.isEmpty || !studies.isEmpty || !sessions.isEmpty {
            print("📱 Found cached data, updating view immediately")
            
            // Update the view with cached data for immediate UI
            view.goals = goals
            view.studies = studies
            view.sessions = sessions
        } else {
            print("📱 No cached data found, will fetch from server")
        }
    }
    
    private func startSyncTimer() {
        // Trigger CloudKit sync every 5 minutes when app is active
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { _ in
            Task {
                await self.dataStore.syncWithCloudKit()
            }
        }
    }
    
    private func syncWithServerIfNeeded() async {
        guard !isPreview else { return }
        
        // Always fetch from server on first launch
        print("📱 Fetching data from server...")
        self.update(.fetchAll)
    }
    

    
    private func sessionFromViewModel(_ sessionView: PracticeSessionView) -> PracticeSession {
        let sessionData = SessionData(
            id: sessionView.id,
            goalIds: sessionView.goalIds,
            intention: sessionView.intention,
            notes: sessionView.notes,
            studySessions: sessionView.studySessions
        )
        
        switch sessionView.state {
        case .notStarted:
            return .notStarted(NotStartedSession(data: sessionData))
        case .started(let startTime):
            return .started(StartedSession(data: sessionData, startTime: startTime))
        case .ended(let startTime, let endTime):
            return .ended(EndedSession(data: sessionData, startTime: startTime, endTime: endTime))
        }
    }

    func update(_ event: Event) {
        print("🔄 Processing event: \(event)")
        
        do {
            let effects = [UInt8](core.update(Data(try event.bincodeSerialize())))

            let requests: [Request] = try .bincodeDeserialize(input: effects)
            for request in requests {
                processEffect(request)
            }
            
            // Save current state to local store after processing effects
            saveToLocalStoreIfNeeded(event)
        } catch {
            if !isPreview {
                print("Warning: Failed to serialize/deserialize update effects: \(error)")
            }
        }
    }
    
    private func saveToLocalStoreIfNeeded(_ event: Event) {
        // Save all current data to local store after any event
        // This ensures we always have the latest state persisted
        dataStore.saveGoals(view.goals)
        dataStore.saveStudies(view.studies)
        dataStore.saveSessions(view.sessions)
    }
    
    private func convertSessionToView(_ session: PracticeSession) -> PracticeSessionView {
        // Convert PracticeSession to PracticeSessionView using the helper methods
        switch session {
        case .notStarted(let notStarted):
            return PracticeSessionView(
                id: notStarted.data.id,
                goalIds: notStarted.data.goalIds,
                intention: notStarted.data.intention,
                state: .notStarted,
                notes: notStarted.data.notes,
                studySessions: notStarted.data.studySessions,
                duration: nil,
                startTime: nil,
                endTime: nil,
                isEnded: false
            )
        case .started(let started):
            return PracticeSessionView(
                id: started.data.id,
                goalIds: started.data.goalIds,
                intention: started.data.intention,
                state: .started(start_time: started.startTime),
                notes: started.data.notes,
                studySessions: started.data.studySessions,
                duration: nil,
                startTime: started.startTime,
                endTime: nil,
                isEnded: false
            )
        case .ended(let ended):
            return PracticeSessionView(
                id: ended.data.id,
                goalIds: ended.data.goalIds,
                intention: ended.data.intention,
                state: .ended(start_time: ended.startTime, end_time: ended.endTime),
                notes: ended.data.notes,
                studySessions: ended.data.studySessions,
                duration: calculateDuration(startTime: ended.startTime, endTime: ended.endTime),
                startTime: ended.startTime,
                endTime: ended.endTime,
                isEnded: true
            )
        }
    }
    
    private func calculateDuration(startTime: String, endTime: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let start = formatter.date(from: startTime),
              let end = formatter.date(from: endTime) else {
            return nil
        }
        let duration = end.timeIntervalSince(start)
        let minutes = Int(duration / 60)
        return "\(minutes)m"
    }

    func processEffect(_ request: Request) {
        switch request.effect {
        case .render:
            DispatchQueue.main.async {
                let bytes = [UInt8](self.core.view())
                if bytes.isEmpty || bytes.count < 4 {
                    if !isPreview {
                        print("Warning: Core returned empty or too-small view data, using default ViewModel")
                    }
                    self.view = Self.createDefaultViewModel()
                } else {
                    do {
                        self.view = try .bincodeDeserialize(input: bytes)
                    } catch {
                        if !isPreview {
                            print("Warning: Failed to deserialize view update: \(error)")
                        }
                        self.view = Self.createDefaultViewModel()
                    }
                }
            }
        case let .http(req):
            print("🌐 Making HTTP request: \(req.method) \(req.url)")
            Task {
                do {
                    let response = try await requestHttp(req).get()
                    print("✅ HTTP request successful: \(req.method) \(req.url)")
                    print("📄 Response body: \(String(data: Data(response.body), encoding: .utf8) ?? "Unable to decode")")
                    
                    let effects = core.resolve(
                        request.id,
                        Data(try HttpResult.ok(response).bincodeSerialize()))
                    
                    // Handle server reconciliation for successful responses
                    self.handleServerReconciliation(req, response)
                    
                    let requests: [Request] = try .bincodeDeserialize(input: [UInt8](effects))
                    print("🔄 Processing \(requests.count) follow-up effects")
                    for request in requests {
                        processEffect(request)
                    }
                } catch {
                    print("❌ HTTP request failed: \(req.method) \(req.url) - Error: \(error)")
                    if !isPreview {
                        print("Warning: Failed to handle HTTP effect: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Server Reconciliation
    
    private func handleServerReconciliation(_ request: HttpRequest, _ response: HttpResponse) {
        // LocalStore automatically handles sync via CloudKit
        // No manual reconciliation needed
        print("✅ Server request successful: \(request.method) \(request.url)")
    }
}


