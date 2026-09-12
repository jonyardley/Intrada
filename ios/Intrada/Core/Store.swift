import Foundation
import SharedTypes

/// Holds the `ViewModel`, sends `Event`s to the core, and runs the effect loop.
/// Owns zero domain logic — a pump between SwiftUI and the core (CLAUDE.md).
@MainActor
@Observable
final class Store {
  private(set) var viewModel: ViewModel?

  /// On-disk store couldn't open → fell back to in-memory, so writes won't
  /// persist. The shell shows a standing warning. False for tests/previews.
  let degraded: Bool

  /// UserDefaults key for the persisted library sort (small singleton — see
  /// CLAUDE.md "only small singletons in crux_kv"; we use the existing
  /// AppEffect path rather than wiring crux_kv for one value).
  static let sortDefaultsKey = "intrada.library-sort"
  /// Positional bincode: any change to `ActiveSession`'s graph takes a new key
  /// (#1345; pinned by the core's `active_session_blob_wire_is_pinned`).
  static let sessionInProgressKey = "intrada.session-in-progress.v3"
  /// Positional bincode too: a field added to `Profile` takes a new key
  /// (`specs/profile.md`; pinned by the core's `profile_blob_wire_is_pinned`).
  static let profileDefaultsKey = "intrada.profile.v1"
  private let bridge: CoreBridge
  private let session: URLSession
  private let store: (any ItemStore)?
  private let sortDefaults: UserDefaults

  init(
    bridge: CoreBridge = LiveBridge(), session: URLSession = .shared,
    store: (any ItemStore)? = nil, sortDefaults: UserDefaults = .standard,
    degraded: Bool = false
  ) {
    self.bridge = bridge
    self.session = session
    self.degraded = degraded
    // Default to in-memory so tests/previews never touch disk; the real app
    // passes an on-disk store. `try?` (not `guarded`) because `self` isn't fully
    // initialized yet here; in-memory creation effectively never fails.
    self.store = store ?? (try? LibraryStore.inMemory())
    self.sortDefaults = sortDefaults
    // Initial render comes straight from the core; nil only if the bridge
    // itself fails, in which case the view shows a loading state.
    self.viewModel = guarded { try bridge.view() }
  }

  func send(_ event: Event) {
    process(guarded { try bridge.update(event) } ?? [])
  }

  private func process(_ requests: [Request]) {
    for request in requests {
      switch request.effect {
      case .render:
        refreshView()
      case .http(let httpRequest):
        Task { await self.handleHttp(httpRequest, id: request.id) }
      case .app(let appEffect):
        // notify_shell effect: fire-and-forget, must not be resolved (#882).
        handleAppEffect(appEffect)
      case .persistence(let operation):
        let output = persistenceOutput(for: operation)
        process(guarded { try bridge.resolve(request.id, persistenceOutput: output) } ?? [])
      case .recognition(let operation):
        Task { await self.handleRecognition(operation, id: request.id) }
      }
    }
  }

  private func handleRecognition(_ operation: RecognitionOperation, id: UInt32) async {
    let output: RecognitionOutput
    switch operation {
    case .readPage(let photoId):
      output = await PageReader.read(photoId: photoId)
    }
    process(guarded { try bridge.resolve(id, recognitionOutput: output) } ?? [])
  }

  private func refreshView() {
    if let next = guarded({ try bridge.view() }) {
      viewModel = next
    }
  }

  private func handleAppEffect(_ effect: AppEffect) {
    switch effect {
    case .saveLibrarySort(let sort):
      if let bytes = guarded({ try sort.bincodeSerialize() }) {
        sortDefaults.set(Data(bytes), forKey: Self.sortDefaultsKey)
      }
    case .saveSessionInProgress(let active):
      if let bytes = guarded({ try active.bincodeSerialize() }) {
        sortDefaults.set(Data(bytes), forKey: Self.sessionInProgressKey)
      }
    case .clearSessionInProgress:
      sortDefaults.removeObject(forKey: Self.sessionInProgressKey)
      recoverableSession = nil
    case .saveProfile(let profile):
      if let bytes = guarded({ try profile.bincodeSerialize() }) {
        sortDefaults.set(Data(bytes), forKey: Self.profileDefaultsKey)
      }
    }
  }

  /// Crash-recovery blob found at launch; non-nil drives the Practice tab's
  /// Resume / Discard prompt (#962).
  var recoverableSession: ActiveSession?

  func pendingSessionInProgress() -> ActiveSession? {
    guard let data = sortDefaults.data(forKey: Self.sessionInProgressKey) else { return nil }
    return guarded { try ActiveSession.bincodeDeserialize(input: [UInt8](data)) }
  }

  func loadRecoverableSession() {
    guard viewModel?.activeSession == nil, viewModel?.summary == nil else { return }
    recoverableSession = pendingSessionInProgress()
  }

  func resumeRecoverableSession() {
    guard let session = recoverableSession else { return }
    send(.session(.recoverSession(session: session, now: SessionClock.nowRFC3339())))
    if viewModel?.activeSession != nil {
      recoverableSession = nil
    }
  }

  /// Pre-recovery discard is pure KV cleanup: the model is Idle, and
  /// AbandonSession (the core's clearing path) requires an Active session (#962).
  func discardSessionInProgress() {
    sortDefaults.removeObject(forKey: Self.sessionInProgressKey)
    recoverableSession = nil
  }

  /// Tell the core which way the device's clock is offset from UTC so
  /// analytics turn the day over at the user's midnight (#1330).
  func reportUtcOffset(_ timeZone: TimeZone = .current) {
    send(.setUtcOffset(minutes: Int32(timeZone.secondsFromGMT() / 60)))
  }

  func restorePersistedSort() {
    guard let data = sortDefaults.data(forKey: Self.sortDefaultsKey),
      let sort = guarded({ try LibrarySort.bincodeDeserialize(input: [UInt8](data)) })
    else { return }
    send(.setSort(sort))
  }

  func forgetPersistedProfile() {
    sortDefaults.removeObject(forKey: Self.profileDefaultsKey)
  }

  func restorePersistedProfile() {
    guard let data = sortDefaults.data(forKey: Self.profileDefaultsKey),
      let profile = guarded({ try Profile.bincodeDeserialize(input: [UInt8](data)) })
    else { return }
    send(.profile(.loaded(profile)))
  }

  private func handleHttp(_ request: HttpRequest, id: UInt32) async {
    let result = await Self.execute(request, session: session)
    process(guarded { try bridge.resolve(id, httpResult: result) } ?? [])
  }

  /// Failure (or no store) → `.failed` so the core surfaces it, not a phantom ack (#816).
  private func persistenceOutput(for operation: PersistenceOperation) -> PersistenceOutput {
    guard let store else { return .failed }
    do {
      switch operation {
      case .loadItems: return .items(try store.loadItems())
      case .saveItem(let item):
        try store.save(item)
        return .ack
      case .saveItems(let items):
        try store.save(items)
        return .ack
      case .deleteItem(let id, let deletedAt):
        try store.delete(id: id, deletedAt: deletedAt)
        return .ack
      case .loadSessions: return .sessions(try store.loadSessions())
      case .saveSession(let session):
        try store.saveSession(session)
        return .ack
      }
    } catch {
      report(error, "persistence")
      return .failed
    }
  }

  // A bridge failure means a serialization/protocol break (e.g. stale bindings
  // vs a regenerated core) — unrecoverable at runtime, so report it rather than
  // swallow it silently, and fail soft.
  private func guarded<T>(_ work: () throws -> T) -> T? {
    do { return try work() } catch {
      report(error, "bridge")
      return nil
    }
  }

  /// No auth yet (foundation scope).
  private static func execute(_ request: HttpRequest, session: URLSession) async -> HttpResult {
    guard let url = URL(string: request.url) else {
      return .err(.url("Invalid URL: \(request.url)"))
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = request.method
    for header in request.headers {
      urlRequest.setValue(header.value, forHTTPHeaderField: header.name)
    }
    if !request.body.isEmpty {
      urlRequest.httpBody = Data(request.body)
    }

    do {
      let (data, response) = try await session.data(for: urlRequest)
      guard let http = response as? HTTPURLResponse else {
        return .err(.io("Invalid response type"))
      }
      let headers: [HttpHeader] = http.allHeaderFields.compactMap { key, value in
        guard let name = key as? String, let val = value as? String else { return nil }
        return HttpHeader(name: name, value: val)
      }
      return .ok(
        HttpResponse(
          status: UInt16(http.statusCode),
          headers: headers,
          body: [UInt8](data)
        ))
    } catch let error as URLError where error.code == .timedOut {
      return .err(.timeout)
    } catch {
      return .err(.io(error.localizedDescription))
    }
  }
}
