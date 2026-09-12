import Foundation
import IntradaCoreFFI
import SharedTypes

/// The sole owner of bincode + the UniFFI core handle. Everything else in the
/// app works against the `CoreBridge` protocol with plain Swift values.
/// (UniFFI de-capitalizes the `CoreFFI` Rust type to `CoreFfi` in Swift.)
final class LiveBridge: CoreBridge {
  private let core = CoreFfi()

  func update(_ event: Event) throws -> [Request] {
    let out = try core.update(data: Data(try event.bincodeSerialize()))
    return try Requests.bincodeDeserialize(input: [UInt8](out)).value
  }

  func resolve(_ id: UInt32, persistenceOutput: PersistenceOutput) throws -> [Request] {
    let out = try core.resolve(id: id, data: Data(try persistenceOutput.bincodeSerialize()))
    return try Requests.bincodeDeserialize(input: [UInt8](out)).value
  }

  func resolve(_ id: UInt32, recognitionOutput: RecognitionOutput) throws -> [Request] {
    let out = try core.resolve(id: id, data: Data(try recognitionOutput.bincodeSerialize()))
    return try Requests.bincodeDeserialize(input: [UInt8](out)).value
  }

  func resolveEmpty(_ id: UInt32) throws -> [Request] {
    let out = try core.resolve(id: id, data: Data())
    return try Requests.bincodeDeserialize(input: [UInt8](out)).value
  }

  func view() throws -> ViewModel {
    try ViewModel.bincodeDeserialize(input: [UInt8](try core.view()))
  }
}
