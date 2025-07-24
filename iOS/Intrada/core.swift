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

    init() {
        self.handler = EffectHandler()
        self.core = CoreFfi(handler)
        
        let bytes = [UInt8](core.view())
        if bytes.isEmpty || bytes.count < 4 {
            if !isPreview {
                print("Warning: Core returned empty or too-small view data, using default ViewModel")
            }
            self.view = ViewModel(
                goals: [],
                studies: [],
                sessions: [],
                activeSession: nil,
                currentSession: nil,
                hasActiveSession: false,
                canStartSession: false,
                canEndSession: false,
                isSessionRunning: false,
                isSessionEnded: false,
                currentSessionElapsedTime: nil
            )
        } else {
            do {
                self.view = try .bincodeDeserialize(input: bytes)
            } catch {
                if !isPreview {
                    print("Warning: Failed to deserialize existing data, starting with fresh state: \(error)")
                }
                self.view = ViewModel(
                    goals: [],
                    studies: [],
                    sessions: [],
                    activeSession: nil,
                    currentSession: nil,
                    hasActiveSession: false,
                    canStartSession: false,
                    canEndSession: false,
                    isSessionRunning: false,
                    isSessionEnded: false,
                    currentSessionElapsedTime: nil
                )
            }
        }
        
        self.update(Event.dev(.setDevData))
        self.update(Event.goal(.fetchGoals))
        self.update(Event.study(.fetchStudies))

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
    }

    func update(_ event: Event) {
        do {
            let effects = [UInt8](core.update(Data(try event.bincodeSerialize())))

            let requests: [Request] = try .bincodeDeserialize(input: effects)
            for request in requests {
                processEffect(request)
            }
        } catch {
            if !isPreview {
                print("Warning: Failed to serialize/deserialize update effects: \(error)")
            }
        }
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
                    self.view = ViewModel(
                        goals: [],
                        studies: [],
                        sessions: [],
                        activeSession: nil,
                        currentSession: nil,
                        hasActiveSession: false,
                        canStartSession: false,
                        canEndSession: false,
                        isSessionRunning: false,
                        isSessionEnded: false,
                        currentSessionElapsedTime: nil
                    )
                } else {
                    do {
                        self.view = try .bincodeDeserialize(input: bytes)
                    } catch {
                        if !isPreview {
                            print("Warning: Failed to deserialize view update: \(error)")
                        }
                        self.view = ViewModel(
                            goals: [],
                            studies: [],
                            sessions: [],
                            activeSession: nil,
                            currentSession: nil,
                            hasActiveSession: false,
                            canStartSession: false,
                            canEndSession: false,
                            isSessionRunning: false,
                            isSessionEnded: false,
                            currentSessionElapsedTime: nil
                        )
                    }
                }
            }
        case let .http(req):
            Task {
                do {
                    let response = try await requestHttp(req).get()
                    
                    let effects = [UInt8](core.resolve(
                        request.id,
                        Data(try HttpResult.ok(response).bincodeSerialize()))
                    )
                    
                    let requests: [Request] = try .bincodeDeserialize(input: effects)
                    for request in requests {
                        processEffect(request)
                    }
                } catch {
                    if !isPreview {
                        print("Warning: Failed to handle HTTP effect: \(error)")
                    }
                }
            }
        }

    }
}
