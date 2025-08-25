import Shared
import SharedTypes
import SwiftUI

// MARK: - Core Observable Wrapper

/// Simple CruxShell implementation for iOS
public class IOSShell: CruxShell {
    public func processEffects(_: Data) {
        // Handle effects here if needed
        // For now, we'll leave this empty as the basic implementation
    }
}

/// Observable wrapper around CoreFfi to make it work with SwiftUI
@MainActor
public class Core: ObservableObject {
    private let coreFfi: CoreFfi

    public init() {
        let shell = IOSShell()
        coreFfi = CoreFfi(shell)
    }

    public var view: ViewModel {
        // Deserialize the Data returned from coreFfi.view() into ViewModel
        let viewData = coreFfi.view()
        do {
            return try ViewModel.bincodeDeserialize(input: Array(viewData))
        } catch {
            fatalError("Failed to deserialize ViewModel: \(error)")
        }
    }

    public func update(_ event: Event) {
        do {
            let eventData = try event.bincodeSerialize()
            _ = coreFfi.update(Data(eventData))
            objectWillChange.send()
        } catch {
            fatalError("Failed to serialize event: \(error)")
        }
    }
}
