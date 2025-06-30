import Foundation
import Shared
import SharedTypes

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
    public let appwriteService = AppwriteService()

    init() {
        self.handler = EffectHandler()
        self.core = CoreFfi(handler)
        self.view = try! .bincodeDeserialize(input: [UInt8](core.view()))
        self.update(Event.setDevData)
        self.update(Event.loadGoals)

        // the handler assignment needs to be deferred, otherwise we create a circular
        // reference between handler and self, before self is done initializing
        handler.handler = { bytes in
            let requests: [Request] = try! .bincodeDeserialize(input: [UInt8](bytes))
            for request in requests {
                self.processEffect(request)
            }
        }
    }

    func update(_ event: Event) {
        let effects = [UInt8](core.update(Data(try! event.bincodeSerialize())))

        let requests: [Request] = try! .bincodeDeserialize(input: effects)
        for request in requests {
            processEffect(request)
        }
    }

    func processEffect(_ request: Request) {
        switch request.effect {
        case .render:
            DispatchQueue.main.async {
                self.view = try! .bincodeDeserialize(input: [UInt8](self.core.view()))
            }
        case let .http(req):
            Task {
                let response = try! await requestHttp(req).get()
                
                let effects = [UInt8](core.resolve(
                    request.id,
                    Data(try! HttpResult.ok(response).bincodeSerialize()))
                )
                
                let requests: [Request] = try! .bincodeDeserialize(input: effects)
                for request in requests {
                    processEffect(request)
                }
            }
        case let .appwrite(operation):
            Task {
                let result = await handleAppwriteOperation(operation)
                
                let effects = [UInt8](core.resolve(
                    request.id,
                    Data(try! result.bincodeSerialize()))
                )
                
                let requests: [Request] = try! .bincodeDeserialize(input: effects)
                for request in requests {
                    processEffect(request)
                }
            }
        }
    }
    
    func handleAppwriteOperation(_ operation: AppwriteOperation) async -> AppwriteResult {
        switch operation {
        case .getGoals:
            do {
                let goals = try await appwriteService.fetchGoals()
                return AppwriteResult.goals(goals)
            } catch {
                return AppwriteResult.error(error.localizedDescription)
            }
        case let .createGoal(goal):
            do {
                let createdGoal = try await appwriteService.createGoal(goal)
                return AppwriteResult.goal(createdGoal)
            } catch {
                return AppwriteResult.error(error.localizedDescription)
            }
        case let .updateGoal(goal):
            do {
                let updatedGoal = try await appwriteService.updateGoal(goal)
                return AppwriteResult.goal(updatedGoal)
            } catch {
                return AppwriteResult.error(error.localizedDescription)
            }
        case let .deleteGoal(goalId):
            do {
                try await appwriteService.deleteGoal(goalId)
                return AppwriteResult.success
            } catch {
                return AppwriteResult.error(error.localizedDescription)
            }
        }
    }
}