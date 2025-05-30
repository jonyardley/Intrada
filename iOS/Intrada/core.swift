import Foundation
import SharedTypes

@MainActor
class Core: ObservableObject {
    @Published var view: ViewModel
    
    init() {
        do {
            self.view = try .bincodeDeserialize(input: [UInt8](Intrada.view()))
        } catch {
            print("Error during deserialization: \(error)")
            self.view = ViewModel(goals: [], exercises: []) // Provide a fallback value
        }
        self.update(.setDevData)
    }
    
    func update(_ event: Event) {
        let effects: [UInt8]
        do {
            effects = [UInt8](processEvent(Data(try event.bincodeSerialize())))
        } catch {
            print("Error during serialization: \(error)")
            effects = [] // Provide a fallback value
        }
        
        let requests: [Request]
        do {
            requests = try .bincodeDeserialize(input: effects)
        } catch {
            print("Error during deserialization: \(error)")
            requests = [] // Provide a fallback value
        }
        for request in requests {
            processEffect(request)
        }
    }
    
    func processEffect(_ request: Request) {
        switch request.effect {
        case .render:
            view = try! .bincodeDeserialize(input: [UInt8](Intrada.view()))
        }
    }
}
