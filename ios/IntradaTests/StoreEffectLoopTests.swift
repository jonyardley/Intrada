import IntradaCoreFFI
import SharedTypes
import XCTest

@testable import Intrada

@MainActor
final class StoreEffectLoopTests: XCTestCase {

  // ── Effect dispatch ────────────────────────────────────────────────────

  func testInitRendersInitialViewModel() {
    let bridge = FakeBridge()
    let store = Store(bridge: bridge)
    XCTAssertNotNil(store.viewModel, "init should seed the ViewModel from the bridge")
    XCTAssertEqual(bridge.viewCallCount, 1)
  }

  func testRenderEffectRefreshesViewModel() {
    let bridge = FakeBridge()
    bridge.updateHandler = { _ in [Request(id: 1, effect: .render(RenderOperation()))] }
    let store = Store(bridge: bridge)

    bridge.nextViewModel = {
      var vm = try emptyViewModel()
      vm.error = "refreshed"
      return vm
    }
    store.send(.setQuery(nil))

    XCTAssertEqual(store.viewModel?.error, "refreshed", "render effect should re-read view()")
  }

  func testSaveSessionInProgressEffectWritesBlobAndClearRemovesIt() throws {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "sip-\(UUID().uuidString)"))
    let active = ActiveSession(
      id: "s-crash", entries: [], currentIndex: 0,
      currentItemStartedAt: "2026-07-14T10:00:00Z", sessionStartedAt: "2026-07-14T10:00:00Z",
      sessionIntention: "even RH at 96")
    let bridge = FakeBridge()
    bridge.updateHandler = { _ in
      [Request(id: 1, effect: .app(.saveSessionInProgress(active)))]
    }
    let store = Store(bridge: bridge, sortDefaults: defaults)

    store.send(.setQuery(nil))

    let pending = try XCTUnwrap(
      store.pendingSessionInProgress(), "the save effect must persist a recoverable blob")
    XCTAssertEqual(pending.id, "s-crash")
    XCTAssertEqual(pending.sessionIntention, "even RH at 96")

    bridge.updateHandler = { _ in [Request(id: 2, effect: .app(.clearSessionInProgress))] }
    store.send(.setQuery(nil))
    XCTAssertNil(
      store.pendingSessionInProgress(), "the clear effect must remove the recoverable blob")
  }

  func testDiscardSessionInProgressRemovesBlobWithoutCoreEvent() throws {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "sip-\(UUID().uuidString)"))
    let active = ActiveSession(
      id: "s-stale", entries: [], currentIndex: 0,
      currentItemStartedAt: "2026-07-14T10:00:00Z", sessionStartedAt: "2026-07-14T10:00:00Z",
      sessionIntention: nil)
    let bridge = FakeBridge()
    bridge.updateHandler = { _ in
      [Request(id: 1, effect: .app(.saveSessionInProgress(active)))]
    }
    let store = Store(bridge: bridge, sortDefaults: defaults)
    store.send(.setQuery(nil))
    store.recoverableSession = store.pendingSessionInProgress()
    XCTAssertNotNil(store.recoverableSession)

    store.discardSessionInProgress()

    XCTAssertNil(store.pendingSessionInProgress())
    XCTAssertNil(store.recoverableSession)
  }

  func testAppEffectIsNotResolved() {
    // Why never resolve: testRealBridgeAppEffectIsNeverResolved (#882).
    let bridge = FakeBridge()
    bridge.updateHandler = { _ in [Request(id: 7, effect: .app(.clearSessionInProgress))] }
    let store = Store(bridge: bridge)

    store.send(.setQuery(nil))

    XCTAssertTrue(bridge.emptyResolved.isEmpty, "app effect must not be resolved")
  }

  func testPersistenceLoadResolvesFromStore() {
    let bridge = FakeBridge()
    bridge.updateHandler = { _ in [Request(id: 8, effect: .persistence(.loadItems))] }
    let store = Store(bridge: bridge)

    store.send(.setQuery(nil))

    XCTAssertEqual(bridge.persistenceResolved.first?.id, 8)
    guard case .items(let items) = bridge.persistenceResolved.first?.output else {
      return XCTFail(
        "expected .items, got \(String(describing: bridge.persistenceResolved.first?.output))")
    }
    XCTAssertTrue(items.isEmpty, "fresh in-memory store has no rows")
  }

  /// The shell's whole job on this effect: run Vision, hand the core back a
  /// `RecognitionOutput`, decide nothing. An id with no bytes behind it is
  /// `Failed`, never a page of no lines (which the core would read as a blank).
  func testRecognitionResolvesFailedForAPhotoThatIsNotOnDisk() async {
    let bridge = FakeBridge()
    bridge.updateHandler = { _ in
      [Request(id: 11, effect: .recognition(.readPage(photoId: Ulid.generate())))]
    }
    let store = Store(bridge: bridge)

    await whenResolved(bridge) { store.send(.setQuery(nil)) }

    XCTAssertEqual(bridge.recognitionResolved.first?.id, 11)
    XCTAssertEqual(bridge.recognitionResolved.first?.output, .failed)
  }

  func testPersistenceWriteFailureResolvesFailed() {
    let bridge = FakeBridge()
    bridge.updateHandler = { _ in
      [Request(id: 9, effect: .persistence(.saveItem(Self.sampleItem)))]
    }
    let store = Store(bridge: bridge, store: FailingStore())

    store.send(.setQuery(nil))

    XCTAssertEqual(
      bridge.persistenceResolved.first?.output, .failed,
      "a failing local store must resolve .failed, not a phantom .ack")
  }

  func testBatchProcessesEveryRequest() {
    let bridge = FakeBridge()
    bridge.updateHandler = { _ in
      [
        Request(id: 1, effect: .app(.clearSessionInProgress)),
        Request(id: 2, effect: .render(RenderOperation())),
      ]
    }
    let store = Store(bridge: bridge)

    bridge.nextViewModel = {
      var vm = try emptyViewModel()
      vm.error = "batched"
      return vm
    }
    store.send(.setQuery(nil))

    XCTAssertTrue(bridge.emptyResolved.isEmpty, "app effect must not be resolved")
    XCTAssertEqual(store.viewModel?.error, "batched", "render after the app effect still runs")
  }

  // ── Library sort persistence ───────────────────────────────────────────

  func testSaveLibrarySortEffectWritesToDefaults() throws {
    let defaults = UserDefaults(suiteName: "sort-test-\(UUID().uuidString)")!
    let sort = LibrarySort(field: .title, direction: .ascending)
    let bridge = FakeBridge()
    bridge.updateHandler = { _ in [Request(id: 5, effect: .app(.saveLibrarySort(sort)))] }
    let store = Store(bridge: bridge, sortDefaults: defaults)

    store.send(.setQuery(nil))

    let data = try XCTUnwrap(defaults.data(forKey: Store.sortDefaultsKey))
    let restored = try LibrarySort.bincodeDeserialize(input: [UInt8](data))
    XCTAssertEqual(restored, sort, "save effect persists the chosen sort")
    XCTAssertTrue(bridge.emptyResolved.isEmpty, "the app effect must not be resolved (#882)")
  }

  func testRestorePersistedSortReplaysSetSort() throws {
    let defaults = UserDefaults(suiteName: "sort-test-\(UUID().uuidString)")!
    let sort = LibrarySort(field: .lastPracticed, direction: .ascending)
    defaults.set(Data(try sort.bincodeSerialize()), forKey: Store.sortDefaultsKey)

    let bridge = FakeBridge()
    var sentEvents: [Event] = []
    bridge.updateHandler = { event in
      sentEvents.append(event)
      return []
    }
    let store = Store(bridge: bridge, sortDefaults: defaults)

    store.restorePersistedSort()

    XCTAssertEqual(
      sentEvents, [.setSort(sort)], "restore re-dispatches SetSort with the stored order")
  }

  func testRestorePersistedSortNoopWhenAbsent() {
    let defaults = UserDefaults(suiteName: "sort-test-\(UUID().uuidString)")!
    let bridge = FakeBridge()
    var sentEvents: [Event] = []
    bridge.updateHandler = { event in
      sentEvents.append(event)
      return []
    }
    let store = Store(bridge: bridge, sortDefaults: defaults)

    store.restorePersistedSort()

    XCTAssertTrue(sentEvents.isEmpty, "no stored sort → no event")
  }

  // ── Profile persistence ────────────────────────────────────────────────

  func testSaveProfileEffectWritesToDefaultsUnderVersionedKey() throws {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "profile-\(UUID().uuidString)"))
    let profile = Profile(name: "Jon", instrument: "Piano", iconChoice: .harp, colour: .sky)
    let bridge = FakeBridge()
    bridge.updateHandler = { _ in [Request(id: 7, effect: .app(.saveProfile(profile)))] }
    let store = Store(bridge: bridge, sortDefaults: defaults)

    store.send(.setQuery(nil))

    let data = try XCTUnwrap(defaults.data(forKey: Store.profileDefaultsKey))
    let restored = try Profile.bincodeDeserialize(input: [UInt8](data))
    XCTAssertEqual(restored, profile, "save effect persists the profile")
    XCTAssertTrue(bridge.emptyResolved.isEmpty, "the app effect must not be resolved (#882)")
  }

  func testRestorePersistedProfileReplaysLoaded() throws {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "profile-\(UUID().uuidString)"))
    let profile = Profile(name: "Jon", instrument: "Cello", iconChoice: nil, colour: .butter)
    defaults.set(Data(try profile.bincodeSerialize()), forKey: Store.profileDefaultsKey)

    let bridge = FakeBridge()
    var sentEvents: [Event] = []
    bridge.updateHandler = { event in
      sentEvents.append(event)
      return []
    }
    let store = Store(bridge: bridge, sortDefaults: defaults)

    store.restorePersistedProfile()

    XCTAssertEqual(
      sentEvents, [.profile(.loaded(profile))],
      "restore replays Loaded, never Save, so nothing is re-validated or re-written")
  }

  func testForgetPersistedProfileRemovesTheBlob() throws {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "profile-\(UUID().uuidString)"))
    let profile = Profile(name: "Jon", instrument: "Cello", iconChoice: nil, colour: .butter)
    defaults.set(Data(try profile.bincodeSerialize()), forKey: Store.profileDefaultsKey)
    let store = Store(bridge: FakeBridge(), sortDefaults: defaults)

    store.forgetPersistedProfile()

    XCTAssertNil(defaults.data(forKey: Store.profileDefaultsKey), "the reset flag's job")
  }

  func testRestorePersistedProfileNoopWhenAbsent() throws {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "profile-\(UUID().uuidString)"))
    let bridge = FakeBridge()
    var sentEvents: [Event] = []
    bridge.updateHandler = { event in
      sentEvents.append(event)
      return []
    }
    let store = Store(bridge: bridge, sortDefaults: defaults)

    store.restorePersistedProfile()

    XCTAssertTrue(sentEvents.isEmpty, "no stored profile, no event")
  }

  // ── Failure-soft (guarded) ─────────────────────────────────────────────

  func testUpdateThrowIsSwallowedWithoutCrashing() {
    let bridge = FakeBridge()
    bridge.throwOnUpdate = TestError()
    let store = Store(bridge: bridge)

    store.send(.setQuery(nil))

    XCTAssertTrue(bridge.persistenceResolved.isEmpty)
    XCTAssertTrue(bridge.emptyResolved.isEmpty)
    XCTAssertNotNil(store.viewModel, "a thrown update should fail soft, not wipe the ViewModel")
  }

  func testViewThrowAtInitLeavesViewModelNil() {
    let bridge = FakeBridge()
    bridge.throwOnView = TestError()
    let store = Store(bridge: bridge)

    XCTAssertNil(store.viewModel, "a thrown view() should leave nil (loading state), not crash")
  }

  func testResolveChainedRenderRefreshesView() {
    let bridge = FakeBridge()
    bridge.updateHandler = { _ in [Request(id: 4, effect: .persistence(.loadItems))] }
    bridge.resolveHandler = { _ in [Request(id: 2, effect: .render(RenderOperation()))] }
    let store = Store(bridge: bridge)

    bridge.nextViewModel = {
      var vm = try emptyViewModel()
      vm.error = "post-resolve"
      return vm
    }
    store.send(.setQuery(nil))

    XCTAssertEqual(
      store.viewModel?.error, "post-resolve", "render from a resolve should refresh view")
  }

  // ── Real bridge (Swift↔Rust bincode round-trip) ────────────────────────

  /// Real-bridge bincode round-trip (#846): calls LiveBridge directly (not via
  /// Store) so a serialization throw surfaces instead of being swallowed by
  /// Store.send's `guarded`.
  func testRealBridgeEditAppliesToViewModel() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Original", kind: .piece, composer: "Bach", key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))

    let afterAdd = try bridge.view()
    XCTAssertEqual(
      afterAdd.items.count, 1,
      "add should land: count=\(afterAdd.items.count) err=\(afterAdd.error ?? "nil")")
    let id = try XCTUnwrap(afterAdd.items.first?.id)

    // Mirrors ItemFormModel.updateInput(): every PATCH field set, type flipped.
    _ = try bridge.update(
      .item(
        .update(
          id: id,
          input: UpdateItem(
            title: "Renamed", kind: .exercise, composer: .some("Bach"), key: .some(nil),
            modality: .some(nil), tempo: .some(nil), notes: .some(nil), tags: nil, priority: nil))))

    let afterEdit = try bridge.view()
    XCTAssertEqual(
      afterEdit.items.first?.title, "Renamed",
      "edited title should apply (err=\(afterEdit.error ?? "nil"))")
    XCTAssertEqual(afterEdit.items.first?.itemType, .exercise, "edited type should apply")
  }

  /// Real-bridge profile round-trip (#846): the Swift-encoded `Profile` must
  /// decode in the core, and the derived view must ride back.
  func testRealBridgeProfileSaveProjectsTheView() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)

    let requests = try bridge.update(
      .profile(
        .save(Profile(name: "  Jon ", instrument: "Double bass", iconChoice: nil, colour: .coral))))
    let saved = requests.compactMap { request -> Profile? in
      if case .app(.saveProfile(let profile)) = request.effect { return profile }
      return nil
    }
    XCTAssertEqual(saved.map(\.name), ["Jon"], "the save effect carries the trimmed profile")

    let view = try bridge.view().profile
    XCTAssertEqual(view.name, "Jon")
    XCTAssertEqual(view.instrument, "Double bass")
    XCTAssertEqual(view.suggestedIcon, .cello)
    XCTAssertEqual(view.icon, .cello)
    XCTAssertEqual(view.colour, .coral)
    XCTAssertTrue(
      ["Morning, Jon", "Afternoon, Jon", "Evening, Jon"].contains(view.greeting),
      "the greeting follows the device clock: \(view.greeting)")

    _ = try bridge.update(
      .profile(
        .loaded(Profile(name: "", instrument: "", iconChoice: .harp, colour: .butter))))
    let reloaded = try bridge.view().profile
    XCTAssertEqual(reloaded.icon, .harp, "the pick wins over the suggestion")
    XCTAssertEqual(reloaded.suggestedIcon, .other)
    XCTAssertEqual(reloaded.greeting, "", "no name means no greeting")
  }

  /// Real-bridge step round-trip (#846, #1083): `AddVariant` pushes a `Variant`
  /// onto the exercise, which then rides the whole `Item` and the derived
  /// ladder back across the bincode wire, a shape the stub bridge can't
  /// exercise. A wire break would drop the ladder silently.
  func testRealBridgeAddVariantSurfacesStepsInViewModel() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Scales", kind: .exercise, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let id = try XCTUnwrap(try bridge.view().items.first?.id)

    _ = try bridge.update(.item(.addVariant(itemId: id, label: "F major")))
    _ = try bridge.update(.item(.addVariant(itemId: id, label: "Bb major")))

    let view = try bridge.view()
    let ex = try XCTUnwrap(view.items.first { $0.id == id })
    XCTAssertEqual(
      ex.variants.map(\.label), ["F major", "Bb major"],
      "steps round-trip the live bridge in ladder order (err=\(view.error ?? "nil"))")
    XCTAssertFalse(ex.variants.contains { $0.isSolid }, "unpractised steps aren't solid")
  }

  /// Real-bridge wire pin (#846, #1467): a `Bool` that never made it across
  /// reads as `false`, so the row would say "steps" about a ladder of keys —
  /// no crash, no error, just the wrong noun.
  func testRealBridgeLadderIsKeysCrossesTheWire() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Shells", kind: .exercise, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let id = try XCTUnwrap(try bridge.view().items.first?.id)

    _ = try bridge.update(.item(.addVariant(itemId: id, label: "F major")))
    _ = try bridge.update(.item(.addVariant(itemId: id, label: "B\u{266D}")))

    let keys = try bridge.view()
    XCTAssertEqual(
      keys.items.first { $0.id == id }?.ladderIsKeys, true,
      "a ladder of key names comes back as keys (err=\(keys.error ?? "nil"))")

    _ = try bridge.update(.item(.addVariant(itemId: id, label: "Hands together")))

    XCTAssertEqual(
      try bridge.view().items.first { $0.id == id }?.ladderIsKeys, false,
      "one non-key rung and the whole ladder is steps")
  }

  /// Real-bridge wire pin for the photo id (#846, #1355): the Swift serializer,
  /// the Rust deserializer and the `ViewModel` projection must all agree on the
  /// new `Item` field and the two new `ItemEvent` variants. A stub bridge
  /// cannot catch a break in any of the three.
  func testRealBridgePhotoIdCrossesTheWireBothWays() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Nocturne", kind: .piece, composer: "Chopin", key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let id = try XCTUnwrap(try bridge.view().items.first?.id)

    _ = try bridge.update(.item(.setPhoto(id: id, photoId: "01ARZ3NDEKTSV4RRFFQ69G5FAV")))

    let afterSet = try bridge.view()
    XCTAssertNil(afterSet.error, "setPhoto should cross the wire cleanly")
    XCTAssertEqual(
      afterSet.items.first { $0.id == id }?.photoId, "01ARZ3NDEKTSV4RRFFQ69G5FAV",
      "the id the screens read comes back through the projection")

    _ = try bridge.update(.item(.clearPhoto(id: id)))

    XCTAssertNil(
      try bridge.view().items.first { $0.id == id }?.photoId,
      "an absent Option must decode as absent, not as the previous value")
  }

  /// Every recognition type is new on the bincode wire, and `f32` is a new
  /// scalar on it. A stub bridge cannot catch a wire break (#846), so this
  /// drives the whole round trip: the effect out, a `RecognitionOutput` built
  /// in Swift back in, and the draft the form will read out of the projection.
  func testRealBridgeReadPhotoFillsTheDraft() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    let photoId = Ulid.generate()

    let requests = try bridge.update(.item(.readPhoto(photoId: photoId)))
    let request = try XCTUnwrap(
      requests.first { if case .recognition = $0.effect { return true } else { return false } },
      "readPhoto should emit a Recognition effect")
    guard case .recognition(.readPage(let asked)) = request.effect else {
      return XCTFail("expected readPage, got \(request.effect)")
    }
    XCTAssertEqual(asked, photoId, "the core names the file the shell just wrote")

    _ = try bridge.resolve(
      request.id,
      recognitionOutput: .page(
        PageReading(
          lines: [
            RecognisedLine(
              text: "Autumn Leaves", x: 0.1, y: 0.08, width: 0.8, height: 0.09, confidence: 0.93),
            RecognisedLine(
              text: "Music by Joseph Kosma", x: 0.1, y: 0.18, width: 0.8, height: 0.03,
              confidence: 0.4),
          ],
          suggested: nil)))

    let recognition = try bridge.view().photoRecognition
    XCTAssertEqual(recognition.status, .ready)
    XCTAssertEqual(recognition.photoId, photoId)
    let draft = try XCTUnwrap(recognition.draft)
    XCTAssertEqual(draft.title?.value, "Autumn Leaves")
    XCTAssertEqual(draft.composer?.value, "Joseph Kosma")
    XCTAssertEqual(draft.title?.source, .recognised)
    XCTAssertEqual(
      try XCTUnwrap(draft.title?.confidence), Float(0.93), accuracy: 0.0001,
      "an f32 has to survive the wire, not arrive as a rounded or byte-swapped number")
    XCTAssertFalse(draft.title?.weak ?? true, "the title was read cleanly")
    XCTAssertTrue(draft.composer?.weak ?? false, "the credit was read weakly")
  }

  /// `CreateItem` gained a field, and it is the field that stops the user
  /// photographing the same page twice (#1436).
  func testRealBridgeCreateCarriesTheScannedPage() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    let photoId = Ulid.generate()

    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Cry Me A River", kind: .piece, composer: "Arthur Hamilton", key: nil,
            modality: nil, tempo: nil, notes: nil, tags: [], photoId: photoId))))

    let view = try bridge.view()
    XCTAssertNil(view.error)
    XCTAssertEqual(
      view.items.first?.photoId, photoId,
      "the page the form was read off has to reach the piece it created")
  }

  /// The shell mints a photo's id (offline-first invariant 3) and the core
  /// refuses any id that is not a ulid, so `Ulid` and Rust's parser have to
  /// agree.
  func testRealBridgeAcceptsAUlidTheShellMinted() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Gymnopedie", kind: .piece, composer: "Satie", key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let id = try XCTUnwrap(try bridge.view().items.first?.id)
    let minted = Ulid.generate()

    _ = try bridge.update(.item(.setPhoto(id: id, photoId: minted)))

    let after = try bridge.view()
    XCTAssertNil(after.error, "the core's validate_photo_id must accept what Ulid mints")
    XCTAssertEqual(after.items.first { $0.id == id }?.photoId, minted)
  }

  /// Real-bridge wire pin for `SetUtcOffset` (#1330): the Swift serializer and
  /// the Rust deserializer must agree on the new Event variant. Semantics are
  /// pinned by core tests; a wire break here surfaces as a throw or an error
  /// in the next view read.
  func testRealBridgeSetUtcOffsetCrossesTheWire() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)

    _ = try bridge.update(.setUtcOffset(minutes: -300))

    XCTAssertNil(try bridge.view().error, "offset report should be a silent success")
  }

  /// Real-bridge rung tag (#846, #1083): `SetEntryVariant` carries an optional
  /// String across the bincode wire (the absent-vs-present hazard). Drive it
  /// through the live bridge and assert it decodes without error.
  func testRealBridgeTagEntryWithVariantDecodesOnWire() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Scales", kind: .exercise, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let itemId = try XCTUnwrap(try bridge.view().items.first?.id)

    _ = try bridge.update(.item(.addVariant(itemId: itemId, label: "F major")))
    let stepId = try XCTUnwrap(try bridge.view().items.first?.variants.first?.id)

    _ = try bridge.update(.session(.startBuilding))
    _ = try bridge.update(.session(.addToSetlist(itemId: itemId)))
    let entryId = try XCTUnwrap(try bridge.view().buildingSetlist?.entries.first?.id)

    _ = try bridge.update(.session(.setEntryVariant(entryId: entryId, variantId: stepId)))
    XCTAssertNil(try bridge.view().error, "tagging a rung must decode on the wire (#846)")
    _ = try bridge.update(.session(.setEntryVariant(entryId: entryId, variantId: nil)))
    XCTAssertNil(try bridge.view().error, "clearing the rung round-trips")
  }

  private func bridgeWithCompletedEntry() throws -> (LiveBridge, String, String) {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Scales", kind: .exercise, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Arpeggios", kind: .exercise, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let ids = try bridge.view().items.map(\.id)
    XCTAssertEqual(ids.count, 2, "two distinct items: addToSetlist is idempotent by item id")

    _ = try bridge.update(.session(.startBuilding))
    for id in ids { _ = try bridge.update(.session(.addToSetlist(itemId: id))) }
    _ = try bridge.update(.session(.startSession(now: "2026-08-28T09:00:00Z")))
    // Advancing completes the first entry; tempo only lands on a completed one.
    _ = try bridge.update(.session(.nextItem(now: "2026-08-28T09:10:00Z")))

    let entries = try XCTUnwrap(try bridge.view().activeSession?.entries)
    XCTAssertEqual(
      entries.first?.status, .completed,
      "the negative test must be asserting against a real completed entry")
    let entry = try XCTUnwrap(entries.first)
    let playId = try XCTUnwrap(
      entry.plays.last?.id, "a completed entry records the stretch it was practised as")
    return (bridge, entry.id, playId)
  }

  /// Real-bridge wire pin for the pass counter (#1367): the timestamped tap
  /// events and the drawn-slots projection cross the bincode wire, and the
  /// core's rule holds end to end: an untouched entry records nothing, and the
  /// first tap writes the target along with itself.
  func testRealBridgeFirstTapWritesTheTargetAndItsTime() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Scales", kind: .exercise, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let id = try XCTUnwrap(try bridge.view().items.first?.id)
    _ = try bridge.update(.session(.startBuilding))
    _ = try bridge.update(.session(.addToSetlist(itemId: id)))
    _ = try bridge.update(.session(.startSession(now: "2026-09-03T09:00:00Z")))

    let untouched = try XCTUnwrap(try bridge.view().activeSession)
    XCTAssertNil(untouched.currentRepTarget, "nothing is recorded before the first tap")
    XCTAssertNil(untouched.currentRepCount)
    XCTAssertNil(untouched.currentRepHistory)
    XCTAssertEqual(untouched.currentRepSlots, 10, "the counter still has slots to draw")

    _ = try bridge.update(.session(.repGotIt(now: "2026-09-03T09:01:00Z")))
    _ = try bridge.update(.session(.repMissed(now: "2026-09-03T09:01:40Z")))

    let tapped = try XCTUnwrap(try bridge.view().activeSession)
    XCTAssertNil(try bridge.view().error)
    XCTAssertEqual(tapped.currentRepTarget, 10, "the first tap wrote the default target")
    XCTAssertEqual(tapped.currentRepCount, 0)
    let history = try XCTUnwrap(tapped.currentRepHistory)
    XCTAssertEqual(history.map(\.action), [.success, .missed])
    XCTAssertEqual(
      history.map { SessionClock.parseRFC3339($0.at) },
      [
        SessionClock.parseRFC3339("2026-09-03T09:01:00Z"),
        SessionClock.parseRFC3339("2026-09-03T09:01:40Z"),
      ], "each tap keeps the time the shell gave it")
  }

  /// Real-bridge wire pin for the honest click (#1499): the row read `♪ = 168`
  /// in 7/8 with the click on group starts; the core must store 84 crotchets
  /// and the pattern that earned it, and both must come back across the wire.
  func testRealBridgeStoresAQuaverTempoAsCrotchetsWithItsPattern() throws {
    let (bridge, entryId, playId) = try bridgeWithCompletedEntry()
    let pattern = ClickState(
      metre: Metre(beats: 7, unit: 8, groups: [3, 2, 2]), sounding: 0b0101001)

    _ = try bridge.update(
      .session(
        .updateEntryTempo(
          entryId: entryId, playId: playId, tempo: 168,
          observed: TempoObservation(userSet: false, clickSounding: true), click: pattern)))

    let entry = try XCTUnwrap(
      try bridge.view().activeSession?.entries.first { $0.id == entryId })
    let play = try XCTUnwrap(entry.plays.last)
    XCTAssertEqual(play.achievedTempo, 84, "stored in crotchets, not quavers")
    XCTAssertEqual(play.clickPattern, pattern)
  }

  /// Real-bridge round trip for the item's metre (#1499): `SetMetre` carries an
  /// optional nested struct with an optional list inside it, the #846 shape.
  func testRealBridgeSetsAndClearsTheItemsMetre() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Take Five", kind: .piece, composer: "Desmond", key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let id = try XCTUnwrap(try bridge.view().items.first?.id)
    let metre = Metre(beats: 5, unit: 4, groups: [3, 2])

    _ = try bridge.update(.item(.setMetre(id: id, metre: metre)))
    XCTAssertEqual(try bridge.view().items.first?.metre, metre)
    XCTAssertNil(try bridge.view().error)

    _ = try bridge.update(.item(.setMetre(id: id, metre: nil)))
    XCTAssertNil(try bridge.view().items.first?.metre)
  }

  /// Real-bridge wire pin for the tempo evidence contract (#1420): the new
  /// `TempoObservation` payload has to cross the bincode wire intact and the
  /// core's ruling has to hold end to end. A wire break would let an
  /// unevidenced default through, and the trend would draw it as a measurement.
  func testRealBridgeRecordsATempoTheUserSetThemselves() throws {
    let (bridge, entryId, playId) = try bridgeWithCompletedEntry()

    _ = try bridge.update(
      .session(
        .updateEntryTempo(
          entryId: entryId, playId: playId, tempo: 132,
          observed: TempoObservation(userSet: true, clickSounding: false), click: nil)))

    let view = try bridge.view()
    XCTAssertNil(view.error, "the observation must decode on the wire (#846)")
    XCTAssertEqual(
      view.activeSession?.entries.first?.plays.last?.achievedTempo, 132,
      "a tempo the user set themselves is a measurement")
  }

  func testRealBridgeDoesNotRecordAnUntouchedPreFill() throws {
    let (bridge, entryId, playId) = try bridgeWithCompletedEntry()

    _ = try bridge.update(
      .session(
        .updateEntryTempo(
          entryId: entryId, playId: playId, tempo: 96,
          observed: TempoObservation(userSet: false, clickSounding: false), click: nil)))

    let view = try bridge.view()
    XCTAssertNil(view.error, "declining to record is a silent success, not an error")
    let play = try XCTUnwrap(
      view.activeSession?.entries.first?.plays.last,
      "the play the tempo was declined for is still on the entry")
    XCTAssertNil(
      play.achievedTempo,
      "a pre-fill nobody looked at leaves no point for the trend to draw")
  }

  /// but returns a nested `ChordChart` + `ScaffoldPreviewView` across the bincode
  /// wire — a shape a stub bridge can't exercise. A bad chart must surface an
  /// error and never store a partial.
  func testRealBridgeSetChordChartDerivesScaffoldPreview() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Autumn Leaves", kind: .piece, composer: "Joseph Kosma", key: "G",
            modality: .minor, tempo: nil, notes: nil, tags: [], photoId: nil))))
    let id = try XCTUnwrap(try bridge.view().items.first?.id)

    _ = try bridge.update(
      .item(.setChordChart(pieceId: id, rawChart: "| Cm7 | F7 | Bbmaj7 |")))
    let ok = try bridge.view()
    let piece = try XCTUnwrap(ok.items.first { $0.id == id })
    let preview = try XCTUnwrap(
      piece.scaffoldPreview, "charted piece derives a preview (err=\(ok.error ?? "nil"))")
    XCTAssertEqual(preview.key, "G")
    XCTAssertEqual(preview.specs.count, 5, "five generators")
    XCTAssertEqual(piece.chordChart?.sections.first?.bars.count, 3, "three bars round-trip")

    // A bad token surfaces an error and leaves the prior chart intact.
    _ = try bridge.update(
      .item(.setChordChart(pieceId: id, rawChart: "| Cm7 | Hxyz |")))
    let bad = try bridge.view()
    XCTAssertNotNil(bad.error, "a parse error must surface, not vanish (#846)")
    XCTAssertEqual(
      bad.items.first { $0.id == id }?.chordChart?.sections.first?.bars.count, 3,
      "a failed parse never overwrites the stored chart")
  }

  /// Real-bridge commit (#1106): `CommitScaffold` carries a `Vec<ScaffoldKind>`
  /// — round-trip it through the live bincode bridge so the write payload can't
  /// silently misalign (#846), and assert the core materialises + links the
  /// selected exercises.
  func testRealBridgeCommitScaffoldLinksExercises() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Autumn Leaves", kind: .piece, composer: "Joseph Kosma", key: "G",
            modality: .minor, tempo: nil, notes: nil, tags: [], photoId: nil))))
    let id = try XCTUnwrap(try bridge.view().items.first?.id)
    _ = try bridge.update(
      .item(.setChordChart(pieceId: id, rawChart: "| Cm7 | F7 | Bbmaj7 |")))

    _ = try bridge.update(
      .item(.commitScaffold(pieceId: id, kinds: [.shells, .guideToneLines])))

    let after = try bridge.view()
    XCTAssertNil(after.error, "commit surfaces no error (err=\(after.error ?? "nil"))")
    let piece = try XCTUnwrap(after.items.first { $0.id == id })
    XCTAssertEqual(piece.linkedExercises.count, 2, "two selected kinds become linked exercises")
    let titles = Swift.Set(piece.linkedExercises.map(\.title))
    XCTAssertTrue(titles.contains("Shells") && titles.contains("Guide-tone lines"))

    // Re-committing the same kinds dedups — no duplicate exercises.
    _ = try bridge.update(.item(.commitScaffold(pieceId: id, kinds: [.shells])))
    let reran = try bridge.view()
    let shells = reran.items.filter { $0.title == "Shells" }
    XCTAssertEqual(shells.count, 1, "re-commit adds no duplicate (#1106 dedup)")
  }

  /// Real-bridge one-pass create (#1390): `AddPieceInFull` carries a nested
  /// `CreateItem`, an optional raw chart and a `Vec<ScaffoldEntry>` whose two
  /// variants have different payload shapes, so a stub bridge cannot prove the
  /// wire holds (#846). Pinned here before any screen sends it.
  func testRealBridgeAddPieceInFullCarriesChartAndExercises() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Shell voicings", kind: .exercise, composer: nil, key: "G",
            modality: nil, tempo: nil, notes: nil, tags: [], photoId: nil))))
    let existingId = try XCTUnwrap(try bridge.view().items.first?.id)

    _ = try bridge.update(
      .item(
        .addPieceInFull(
          piece: CreateItem(
            title: "Autumn Leaves", kind: .piece, composer: "Joseph Kosma", key: "G",
            modality: .minor, tempo: nil, notes: nil, tags: [], photoId: nil),
          chart: "| Cm7 | F7 | Bbmaj7 |",
          exercises: [
            .existing(id: existingId),
            .new(
              CreateItem(
                title: "Enclosures", kind: .exercise, composer: nil, key: nil, modality: nil,
                tempo: nil, notes: nil, tags: [], photoId: nil)),
          ])))

    let after = try bridge.view()
    XCTAssertNil(after.error, "the one-pass create surfaces no error")
    let piece = try XCTUnwrap(after.items.first { $0.title == "Autumn Leaves" })
    XCTAssertEqual(
      piece.chordChart?.sections.first?.bars.count, 3,
      "the chart parsed on the way in, with no second event")
    XCTAssertEqual(
      piece.linkedExercises.map(\.title), ["Shell voicings", "Enclosures"],
      "chosen then written, in the order given: neither minting order nor sorted")

    // A bar the parser rejects writes nothing at all: no piece, no exercise.
    _ = try bridge.update(
      .item(
        .addPieceInFull(
          piece: CreateItem(
            title: "Blue in Green", kind: .piece, composer: nil, key: "G", modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil),
          chart: "| Cm7 | Hxyz |",
          exercises: [
            .new(
              CreateItem(
                title: "Orphan", kind: .exercise, composer: nil, key: nil, modality: nil,
                tempo: nil, notes: nil, tags: [], photoId: nil))
          ])))

    let rejected = try bridge.view()
    XCTAssertNotNil(rejected.error, "a parse error must surface, not vanish (#846)")
    XCTAssertNil(
      rejected.items.first { $0.title == "Blue in Green" }, "no half-made piece is left behind")
    XCTAssertNil(rejected.items.first { $0.title == "Orphan" }, "and no orphan exercise either")
  }

  /// Real-bridge error target (#1595): three variants with different payload
  /// shapes, one of them a nested optional enum, so only the live bridge proves
  /// the wire holds (#846). The screens read this to point at the failure.
  func testRealBridgeRejectedCreateCarriesWhereItFailed() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)

    _ = try bridge.update(
      .item(
        .addPieceInFull(
          piece: CreateItem(
            title: "Blue in Green", kind: .piece, composer: "Bill Evans", key: "G",
            modality: nil, tempo: nil, notes: nil, tags: [], photoId: nil),
          chart: "| Cm7 | Hxyz |",
          exercises: [])))

    XCTAssertEqual(
      try bridge.view().errorTarget, .chartBar(barNumber: 2, token: "Hxyz"),
      "the bar and the token, so the chart section can highlight in place")

    _ = try bridge.update(
      .item(
        .addPieceInFull(
          piece: CreateItem(
            title: "Blue in Green", kind: .piece, composer: "Bill Evans", key: "G",
            modality: nil, tempo: nil, notes: nil, tags: [], photoId: nil),
          chart: "swing feel",
          exercises: [])))

    XCTAssertEqual(
      try bridge.view().errorTarget, .chart,
      "prose with no bars fails at no bar, so the whole section is what is marked")

    _ = try bridge.update(
      .item(
        .addPieceInFull(
          piece: CreateItem(
            title: "Blue in Green", kind: .piece, composer: "Bill Evans", key: "G",
            modality: nil, tempo: nil, notes: nil, tags: [], photoId: nil),
          chart: nil,
          exercises: [
            .new(
              CreateItem(
                title: "Enclosures", kind: .exercise, composer: nil, key: nil, modality: nil,
                tempo: nil, notes: nil, tags: [], photoId: nil)),
            .new(
              CreateItem(
                title: "   ", kind: .exercise, composer: nil, key: nil, modality: nil,
                tempo: nil, notes: nil, tags: [], photoId: nil)),
          ])))

    XCTAssertEqual(
      try bridge.view().errorTarget, .exercise(index: 1, field: .title),
      "the second row is the blank one, and its title is what to mark")

    _ = try bridge.update(
      .item(
        .addPieceInFull(
          piece: CreateItem(
            title: "Blue in Green", kind: .piece, composer: String(repeating: "x", count: 201),
            key: "G", modality: nil, tempo: nil, notes: nil, tags: [], photoId: nil),
          chart: nil,
          exercises: [])))

    XCTAssertEqual(try bridge.view().errorTarget, .piece(field: .composer))

    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "", kind: .exercise, composer: nil, key: nil, modality: nil, tempo: nil,
            notes: nil, tags: [], photoId: nil))))

    let unrelated = try bridge.view()
    XCTAssertNotNil(unrelated.error, "an ordinary create still reports what went wrong")
    XCTAssertNil(
      unrelated.errorTarget, "but must not leave the form pointing at the last failure")
  }

  /// Real-bridge priority toggle (#763): the star sends an UpdateItem with every
  /// optional field "no change" (outer nil) and only `priority` set — a different
  /// bincode shape than the full edit, so round-trip it through the live bridge to
  /// catch an absent-vs-present wire break (#846).
  func testRealBridgePriorityToggleAppliesToViewModel() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Etude", kind: .piece, composer: "Chopin", key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let item = try XCTUnwrap(try bridge.view().items.first)
    XCTAssertFalse(item.priority, "new items start non-priority")

    func toggle(_ on: Bool) -> Event {
      .item(
        .update(
          id: item.id,
          input: UpdateItem(
            title: item.title, kind: item.itemType,
            composer: nil, key: nil, modality: nil, tempo: nil, notes: nil,
            tags: nil, priority: on)))
    }

    _ = try bridge.update(toggle(true))
    let on = try bridge.view().items.first
    XCTAssertEqual(on?.priority, true, "star should flip priority on")
    XCTAssertEqual(on?.subtitle, "Chopin", "a priority-only update must not clobber other fields")

    _ = try bridge.update(toggle(false))
    XCTAssertEqual(try bridge.view().items.first?.priority, false, "star should flip priority off")
  }

  /// "Practise this" (#1034): StartBuildingWith is a new bridge-crossing
  /// write — round-trip it through the real bincode bridge (#846).
  func testRealBridgePractiseThisSeedsBuilder() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Hanon No. 1", kind: .exercise, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let itemId = try XCTUnwrap(try bridge.view().items.first?.id)

    _ = try bridge.update(.session(.startBuildingWith(itemId: itemId)))
    let vm = try bridge.view()
    XCTAssertNotNil(vm.buildingSetlist, "startBuildingWith should open a seeded setlist")
    XCTAssertEqual(vm.buildingSetlist?.entries.count, 1)
    XCTAssertEqual(vm.buildingSetlist?.entries.first?.itemId, itemId)
    XCTAssertNil(vm.error)
  }

  /// "Practise your priorities" (#981): the event carries a timestamp, which is
  /// a different bincode shape than the itemId write above. A wire break would
  /// open an empty builder rather than fail, which is the #846 shape.
  func testRealBridgePrioritiesSeedTheBuilder() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)

    for title in ["Hanon No. 1", "Scales"] {
      _ = try bridge.update(
        .item(
          .add(
            CreateItem(
              title: title, kind: .exercise, composer: nil, key: nil, modality: nil,
              tempo: nil, notes: nil, tags: [], photoId: nil))))
    }
    for item in try bridge.view().items {
      _ = try bridge.update(
        .item(
          .update(
            id: item.id,
            input: UpdateItem(
              title: item.title, kind: item.itemType, composer: nil, key: nil, modality: nil,
              tempo: nil, notes: nil, tags: nil, priority: true))))
    }
    XCTAssertTrue(try bridge.view().hasPriorities, "both items are starred")

    _ = try bridge.update(.session(.startBuildingWithPriorities(now: SessionClock.nowRFC3339())))
    let vm = try bridge.view()
    XCTAssertEqual(
      vm.buildingSetlist?.entries.count, 2, "every starred item should reach the builder")
    XCTAssertNil(vm.error)
  }

  /// Real-bridge build→play→save lifecycle (#932): drives the actual bincode
  /// bridge through Building → Active → Summary → Idle, mirroring the
  /// SessionBuilder → FocusPlayer → Summary screens. A wire break surfaces here
  /// as a failed transition instead of the silent no-op the stub bridge would
  /// hide (#846).
  func testRealBridgeSessionFlowBuildPlaySave() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Etude", kind: .piece, composer: "Chopin", key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let itemId = try XCTUnwrap(try bridge.view().items.first?.id)

    _ = try bridge.update(.session(.startBuilding))
    _ = try bridge.update(.session(.addToSetlist(itemId: itemId)))
    let building = try bridge.view()
    XCTAssertNotNil(building.buildingSetlist, "startBuilding + add should open a setlist")
    XCTAssertEqual(building.buildingSetlist?.entries.count, 1)
    XCTAssertNil(building.activeSession)

    _ = try bridge.update(.session(.startSession(now: "2026-06-16T10:00:00Z")))
    let active = try bridge.view()
    XCTAssertNotNil(active.activeSession, "startSession should enter the player")
    XCTAssertNil(active.buildingSetlist, "the builder should close on start")
    XCTAssertNil(active.summary)

    // The FocusPlayer reaches the summary by advancing past the last item (its
    // Done/Finish path), not finishSession — round-trip the event the screen
    // actually sends.
    _ = try bridge.update(.session(.nextItem(now: "2026-06-16T10:20:00Z")))
    let summary = try bridge.view()
    XCTAssertNotNil(summary.summary, "advancing past the last item should reach the summary")
    XCTAssertNil(summary.activeSession)

    // Optional-payload events crossing bincode (the absent-vs-present wire
    // hazard, #846): set then clear a score and the session notes.
    let entryId = try XCTUnwrap(summary.summary?.entries.first?.id)
    let playId = try XCTUnwrap(summary.summary?.entries.first?.plays.last?.id)
    _ = try bridge.update(
      .session(.updateEntryScore(entryId: entryId, playId: playId, score: 4)))
    XCTAssertEqual(
      try bridge.view().summary?.entries.first?.plays.last?.score, 4,
      "score should round-trip")
    _ = try bridge.update(
      .session(.updateEntryScore(entryId: entryId, playId: playId, score: nil)))
    XCTAssertNil(
      try bridge.view().summary?.entries.first?.plays.last?.score,
      "clearing a score round-trips")
    // Per-entry notes — the hand-off reflection sheet's write, never previously
    // sent from Swift (#846). Round-trip set + clear through the live bridge.
    _ = try bridge.update(
      .session(.updateEntryNotes(entryId: entryId, notes: "RH evenness better at 96")))
    XCTAssertEqual(
      try bridge.view().summary?.entries.first?.notes, "RH evenness better at 96",
      "the reflection sheet's per-entry note should round-trip")
    _ = try bridge.update(.session(.updateEntryNotes(entryId: entryId, notes: nil)))
    XCTAssertNil(
      try bridge.view().summary?.entries.first?.notes, "clearing an entry note round-trips")
    // Achieved tempo — the hand-off sheet's TempoStepper write, never previously
    // sent from Swift (#846). Round-trip set + clear through the live bridge.
    _ = try bridge.update(
      .session(
        .updateEntryTempo(
          entryId: entryId, playId: playId, tempo: 96,
          observed: TempoObservation(userSet: true, clickSounding: false), click: nil)))
    XCTAssertEqual(
      try bridge.view().summary?.entries.first?.plays.last?.achievedTempo, 96,
      "the tempo stepper's achieved tempo should round-trip")
    _ = try bridge.update(
      .session(
        .updateEntryTempo(
          entryId: entryId, playId: playId, tempo: nil,
          observed: TempoObservation(userSet: true, clickSounding: false), click: nil)))
    XCTAssertNil(
      try bridge.view().summary?.entries.first?.plays.last?.achievedTempo,
      "clearing an achieved tempo round-trips")
    _ = try bridge.update(.session(.updateSessionNotes(notes: "Felt good")))
    XCTAssertEqual(try bridge.view().summary?.notes, "Felt good", "notes should round-trip")
    _ = try bridge.update(.session(.updateSessionNotes(notes: nil)))
    XCTAssertNil(try bridge.view().summary?.notes, "clearing notes round-trips")
    // Structured reflection — a brand-new wire surface (ReflectionField's
    // variant indices) never sent from Swift before (#846). Set + clear each.
    _ = try bridge.update(
      .session(.updateSessionReflection(field: .improved, text: "thumb-unders even")))
    XCTAssertEqual(
      try bridge.view().summary?.reflectionImproved, "thumb-unders even",
      "reflection 'improved' should round-trip the live bridge")
    _ = try bridge.update(
      .session(.updateSessionReflection(field: .stillRough, text: "bridge rushes")))
    XCTAssertEqual(try bridge.view().summary?.reflectionStillRough, "bridge rushes")
    _ = try bridge.update(
      .session(.updateSessionReflection(field: .nextTarget, text: "bridge at 80")))
    XCTAssertEqual(try bridge.view().summary?.reflectionNextTarget, "bridge at 80")
    _ = try bridge.update(.session(.updateSessionReflection(field: .improved, text: nil)))
    XCTAssertNil(
      try bridge.view().summary?.reflectionImproved, "clearing a reflection round-trips")

    _ = try bridge.update(.session(.saveSession(now: "2026-06-16T10:20:30Z")))
    let saved = try bridge.view()
    XCTAssertNil(saved.summary, "saveSession clears the summary (session persisted)")
    XCTAssertNil(saved.activeSession)
    XCTAssertNil(saved.error, "a clean save surfaces no error")

    // Crash recovery — RecoverSession (with its new `now` re-anchor field) has
    // never crossed the live bridge from Swift before (#846, #962). The stale
    // anchor must come back re-anchored to the `now` we send.
    let blobEntry = SetlistEntry(
      id: "re1", itemId: "i1", itemTitle: "Recovered Scales", itemType: .exercise,
      position: 0, durationSecs: 0, status: .notAttempted,
      notes: nil, intention: nil, plannedDurationSecs: nil,
      groupId: nil, plannedVariationId: nil, plannedRepTarget: nil, plays: [])
    let blob = ActiveSession(
      id: "recovered", entries: [blobEntry], currentIndex: 0,
      currentItemStartedAt: "2026-06-16T08:00:00Z", sessionStartedAt: "2026-06-16T08:00:00Z",
      sessionIntention: nil)
    _ = try bridge.update(.session(.recoverSession(session: blob, now: "2026-06-16T11:00:00Z")))
    let recovered = try bridge.view()
    XCTAssertEqual(recovered.activeSession?.currentItemTitle, "Recovered Scales")
    XCTAssertEqual(
      recovered.activeSession?.currentItemStartedAt, "2026-06-16T11:00:00+00:00",
      "recovery must re-anchor the running item's timer to `now`")
    _ = try bridge.update(.session(.abandonSession))
    XCTAssertNil(try bridge.view().activeSession, "abandon after recover returns to Idle")
  }

  /// Real-bridge step-ladder lifecycle (#1083 C1): SetVariants and
  /// UpdateEntryVariant have never crossed the live bincode bridge from Swift
  /// before; a wire break here is the silent no-op class (#846). Drives
  /// ladder create → reorder-preserves-ids → per-entry attribution set/clear.
  func testRealBridgeStepLadderAndEntryAttribution() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Shells", kind: .exercise, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let exId = try XCTUnwrap(try bridge.view().items.first?.id)

    _ = try bridge.update(.item(.setVariants(id: exId, labels: ["C", "F", "B♭"])))
    let afterSet = try bridge.view()
    let ladder = try XCTUnwrap(afterSet.items.first?.variants)
    XCTAssertEqual(
      ladder.map(\.label), ["C", "F", "B♭"],
      "the ladder should land (err=\(afterSet.error ?? "nil"))")
    XCTAssertTrue(ladder.allSatisfy { !$0.isSolid }, "an unrated ladder has no solid steps")
    let stepId = try XCTUnwrap(ladder.first?.id)

    // Reorder must keep ids (and so score history); reconcile-by-label.
    _ = try bridge.update(.item(.setVariants(id: exId, labels: ["F", "C", "B♭"])))
    let reordered = try XCTUnwrap(try bridge.view().items.first?.variants)
    XCTAssertEqual(
      reordered.first { $0.label == "C" }?.id, stepId, "reordering keeps each step's id")

    // #1739 makes SetEntryVariant the builder's plan, so set + clear it there.
    _ = try bridge.update(.session(.startBuilding))
    _ = try bridge.update(.session(.addToSetlist(itemId: exId)))
    let entryId = try XCTUnwrap(try bridge.view().buildingSetlist?.entries.first?.id)

    _ = try bridge.update(.session(.setEntryVariant(entryId: entryId, variantId: stepId)))
    let attributed = try bridge.view()
    XCTAssertEqual(
      attributed.buildingSetlist?.entries.first?.plannedVariationId, stepId,
      "the step attribution should round-trip (err=\(attributed.error ?? "nil"))")
    _ = try bridge.update(.session(.setEntryVariant(entryId: entryId, variantId: nil)))
    XCTAssertNil(
      try bridge.view().buildingSetlist?.entries.first?.plannedVariationId,
      "clearing the attribution round-trips")
  }

  /// App effects come from `notify_shell` — fire-and-forget notifications the
  /// live bridge rejects resolving, so the Store must not resolve `.app`. The
  /// stub bridge can't enforce this; pinned here against the real bridge (#882).
  func testRealBridgeAppEffectIsNeverResolved() throws {
    let bridge = LiveBridge()
    let requests = try bridge.update(
      .setSort(LibrarySort(field: .title, direction: .ascending)))
    let appRequest = try XCTUnwrap(
      requests.first { if case .app = $0.effect { return true } else { return false } },
      "setSort should emit an App (SaveLibrarySort) effect")

    XCTAssertThrowsError(try bridge.resolveEmpty(appRequest.id))
  }

  // ── Real bridge (full-field contract, #846 class) ──────────────────────

  /// Real-bridge full-field round trip for `LibraryItemView` (#846): every
  /// real-bridge test above drives one setter and spot-checks the field it
  /// touches, so a wire break on a DIFFERENT field of this 24-field
  /// projection would pass every one of them. This pins every field the
  /// create/patch pair populates, plus the empty/nil shape of the rest, so a
  /// positional bincode break (which shifts later fields into garbage, the
  /// dangerous #846 case) fails here even when its own dedicated test stays
  /// green. The one case this cannot see is a trailing field dropping to its
  /// own default; that field's dedicated setter test above covers it.
  func testRealBridgeItemCreateAndPatchPreservesEveryField() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    let photoId = Ulid.generate()

    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Nocturne in E-flat", kind: .piece, composer: "Chopin", key: "E\u{266D}",
            modality: .major, tempo: Tempo(marking: "Andante", bpm: 92),
            notes: "Practise slowly, hands separately", tags: ["romantic", "chopin"],
            photoId: photoId))))

    let created = try XCTUnwrap(try bridge.view().items.first)
    XCTAssertFalse(created.id.isEmpty, "the core must mint an id")
    XCTAssertEqual(created.itemType, .piece)
    XCTAssertEqual(created.title, "Nocturne in E-flat")
    XCTAssertEqual(created.subtitle, "Chopin", "subtitle mirrors the composer")
    XCTAssertEqual(created.key, "E\u{266D}")
    XCTAssertEqual(created.modality, .major)
    XCTAssertEqual(created.tempoMarking, "Andante")
    XCTAssertEqual(created.tempoBpm, 92)
    XCTAssertEqual(created.tempo, "Andante (92 BPM)")
    XCTAssertEqual(created.notes, "Practise slowly, hands separately")
    XCTAssertEqual(created.tags, ["romantic", "chopin"])
    XCTAssertNotNil(
      SessionClock.parseRFC3339(created.createdAt), "createdAt must be a real RFC3339 stamp")
    XCTAssertNotNil(
      SessionClock.parseRFC3339(created.updatedAt), "updatedAt must be a real RFC3339 stamp")
    XCTAssertEqual(created.priority, false)
    XCTAssertTrue(created.linkedExercises.isEmpty)
    XCTAssertTrue(created.usedIn.isEmpty)
    XCTAssertNil(created.scaffoldPreview)
    XCTAssertNil(created.chordChart)
    XCTAssertNil(created.metre)
    XCTAssertTrue(created.variants.isEmpty)
    XCTAssertEqual(created.ladderIsKeys, false)
    XCTAssertEqual(created.photoId, photoId)
    XCTAssertNil(created.practice)
    XCTAssertNil(created.latestAchievedTempo)

    // Every PATCH field flipped or cleared in one update (mirrors the shell's
    // ItemFormModel.updateInput()). A field the wire drops silently would
    // leave the OLD value here rather than throwing, so every one is checked.
    _ = try bridge.update(
      .item(
        .update(
          id: created.id,
          input: UpdateItem(
            title: "Nocturne in E-flat (revised)", kind: .piece,
            composer: .some("Chopin (ed. Cortot)"), key: .some("D"), modality: .some(nil),
            tempo: .some(nil), notes: .some(nil), tags: ["romantic", "edited"], priority: true))))

    let view = try bridge.view()
    XCTAssertNil(view.error, "the full patch must decode cleanly (#846)")
    let patched = try XCTUnwrap(view.items.first { $0.id == created.id })
    XCTAssertEqual(patched.title, "Nocturne in E-flat (revised)")
    XCTAssertEqual(patched.itemType, .piece, "kind unchanged, so it must still read piece")
    XCTAssertEqual(patched.subtitle, "Chopin (ed. Cortot)")
    XCTAssertEqual(patched.key, "D")
    XCTAssertNil(patched.modality, "modality was cleared")
    XCTAssertNil(patched.tempoMarking, "tempo was cleared")
    XCTAssertNil(patched.tempoBpm, "tempo was cleared")
    XCTAssertNil(patched.tempo, "tempo was cleared")
    XCTAssertNil(patched.notes, "notes were cleared")
    XCTAssertEqual(patched.tags, ["romantic", "edited"])
    XCTAssertEqual(patched.priority, true)
    XCTAssertEqual(
      patched.photoId, photoId,
      "a patch that never mentions the photo must preserve it: guards the update reconciliation, not just the wire"
    )
  }

  /// Real-bridge full-field round trip for the item's nested shapes (#846,
  /// #1499, #1106): `ChordChart`'s chord-by-chord structure, the derived
  /// `ScaffoldPreviewView`, the piece's `Metre`, and the exercises
  /// `CommitScaffold` links are four different bincode shapes layered on one
  /// item. Existing real-bridge tests spot-check one field of each; this pins
  /// every field so a wire break in any of them can't hide behind the others
  /// looking fine.
  func testRealBridgeItemNestedShapesPreserveEveryField() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Autumn Leaves", kind: .piece, composer: "Joseph Kosma", key: "G",
            modality: .minor, tempo: nil, notes: nil, tags: [], photoId: nil))))
    let id = try XCTUnwrap(try bridge.view().items.first?.id)
    let metre = Metre(beats: 3, unit: 4, groups: [3])

    _ = try bridge.update(.item(.setMetre(id: id, metre: metre)))
    _ = try bridge.update(
      .item(.setChordChart(pieceId: id, rawChart: "| Cm7 F7 | Bbmaj7 Ebmaj7 | Am7b5 D7 | Gm6 |")))
    _ = try bridge.update(.item(.commitScaffold(pieceId: id, kinds: [.shells, .guideToneLines])))

    let view = try bridge.view()
    XCTAssertNil(view.error, "every nested write must decode cleanly (err=\(view.error ?? "nil"))")
    let piece = try XCTUnwrap(view.items.first { $0.id == id })

    XCTAssertEqual(piece.metre, metre)

    let chart = try XCTUnwrap(piece.chordChart)
    XCTAssertEqual(chart.key, "G")
    XCTAssertEqual(chart.modality, .minor)
    XCTAssertEqual(chart.sections.count, 1, "one line, no section labels")
    let bars = chart.sections[0].bars
    XCTAssertEqual(bars.count, 4)
    func chord(_ bar: Int, _ index: Int) -> ChordSymbol { bars[bar].chords[index].symbol }
    XCTAssertEqual(bars[0].chords.count, 2)
    XCTAssertEqual(
      chord(0, 0), ChordSymbol(root: 0, quality: .min7, extensions: [], bass: nil, raw: "Cm7"))
    XCTAssertEqual(
      chord(0, 1), ChordSymbol(root: 5, quality: .dom7, extensions: [], bass: nil, raw: "F7"))
    XCTAssertEqual(
      chord(1, 0), ChordSymbol(root: 10, quality: .maj7, extensions: [], bass: nil, raw: "Bbmaj7"))
    XCTAssertEqual(
      chord(1, 1), ChordSymbol(root: 3, quality: .maj7, extensions: [], bass: nil, raw: "Ebmaj7"))
    XCTAssertEqual(
      chord(2, 0), ChordSymbol(root: 9, quality: .min7b5, extensions: [], bass: nil, raw: "Am7b5"))
    XCTAssertEqual(
      chord(2, 1), ChordSymbol(root: 2, quality: .dom7, extensions: [], bass: nil, raw: "D7"))
    XCTAssertEqual(
      chord(3, 0), ChordSymbol(root: 7, quality: .min6, extensions: [], bass: nil, raw: "Gm6"))

    let preview = try XCTUnwrap(piece.scaffoldPreview)
    XCTAssertEqual(preview.key, "G")
    XCTAssertEqual(preview.specs.count, 5, "five generators")
    XCTAssertEqual(preview.fallbackTotal, 0, "every chord above is in the known vocabulary")

    XCTAssertEqual(piece.linkedExercises.count, 2)
    let byTitle = Dictionary(uniqueKeysWithValues: piece.linkedExercises.map { ($0.title, $0) })
    for title in ["Shells", "Guide-tone lines"] {
      let exercise = try XCTUnwrap(byTitle[title])
      XCTAssertFalse(exercise.id.isEmpty)
      XCTAssertEqual(
        exercise.key, "G", "a scaffold-derived exercise is generated in the piece's key")
      XCTAssertNil(exercise.tempo)
      XCTAssertNil(exercise.practice, "never practised yet")
      XCTAssertNil(exercise.pieceContextScore, "never scored against this piece yet")
    }
  }

  /// Real-bridge full-field round trip for `SetlistEntryView` and the
  /// `VariationPlayView` under it (#846, #1083, #1420, #1499, #1739): drives
  /// every setter that reaches a single entry (intention, rep target, planned
  /// duration, ladder attribution, block grouping, reps, tempo + click pattern,
  /// notes, score) and asserts every field of the resulting projection, so a
  /// dropped field anywhere in that pair fails here even though each setter's
  /// own dedicated spot-check elsewhere would stay green.
  func testRealBridgeSessionEntryFullFieldRoundTrip() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Prelude in C", kind: .piece, composer: "J.S. Bach", key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let pieceId = try XCTUnwrap(try bridge.view().items.first?.id)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Hanon No. 1", kind: .exercise, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let exerciseId = try XCTUnwrap(try bridge.view().items.first { $0.id != pieceId }?.id)
    _ = try bridge.update(.item(.linkExercise(pieceId: pieceId, exerciseId: exerciseId)))
    _ = try bridge.update(.item(.addVariant(itemId: exerciseId, label: "Slow")))
    let variantId = try XCTUnwrap(
      try bridge.view().items.first { $0.id == exerciseId }?.variants.first?.id)

    _ = try bridge.update(.session(.startBuilding))
    _ = try bridge.update(.session(.addToSetlist(itemId: pieceId)))
    let building = try bridge.view()
    let entry = try XCTUnwrap(
      building.buildingSetlist?.entries.first { $0.itemId == exerciseId },
      "the linked exercise should form a block with the piece")
    let entryId = entry.id
    let groupId = try XCTUnwrap(entry.groupId, "the piece's related exercise forms a block")

    _ = try bridge.update(
      .session(.setEntryIntention(entryId: entryId, intention: "Warm up before the Prelude")))
    _ = try bridge.update(.session(.setRepTarget(entryId: entryId, target: 3)))
    _ = try bridge.update(.session(.setEntryDuration(entryId: entryId, durationSecs: 300)))
    _ = try bridge.update(.session(.setEntryVariant(entryId: entryId, variantId: variantId)))

    _ = try bridge.update(.session(.startSession(now: "2026-09-04T09:00:00Z")))
    _ = try bridge.update(.session(.repMissed(now: "2026-09-04T09:01:00Z")))
    _ = try bridge.update(.session(.repGotIt(now: "2026-09-04T09:02:00Z")))
    _ = try bridge.update(.session(.repGotIt(now: "2026-09-04T09:03:00Z")))
    _ = try bridge.update(.session(.repGotIt(now: "2026-09-04T09:03:30Z")))
    _ = try bridge.update(.session(.nextItem(now: "2026-09-04T09:04:00Z")))

    let playId = try XCTUnwrap(
      try bridge.view().activeSession?.entries.first { $0.id == entryId }?.plays.last?.id,
      "the completed entry records the stretch it was practised as")

    let click = ClickState(metre: Metre(beats: 4, unit: 8, groups: [2, 2]), sounding: 0b0101)
    _ = try bridge.update(
      .session(
        .updateEntryTempo(
          entryId: entryId, playId: playId, tempo: 176,
          observed: TempoObservation(userSet: false, clickSounding: true), click: click)))
    _ = try bridge.update(
      .session(.updateEntryNotes(entryId: entryId, notes: "Fingers not fully relaxed yet")))
    _ = try bridge.update(
      .session(.updateEntryScore(entryId: entryId, playId: playId, score: 6)))

    _ = try bridge.update(.session(.nextItem(now: "2026-09-04T09:10:00Z")))

    let view = try bridge.view()
    XCTAssertNil(view.error, "every setter must decode cleanly (#846)")
    let summary = try XCTUnwrap(view.summary)
    let final = try XCTUnwrap(summary.entries.first { $0.id == entryId })

    XCTAssertEqual(final.itemId, exerciseId)
    XCTAssertEqual(final.itemTitle, "Hanon No. 1")
    XCTAssertEqual(final.itemType, .exercise)
    XCTAssertEqual(final.position, 0, "the related exercise leads the block")
    XCTAssertFalse(final.durationDisplay.isEmpty)
    XCTAssertEqual(final.status, .completed)
    XCTAssertEqual(final.notes, "Fingers not fully relaxed yet")
    XCTAssertEqual(final.intention, "Warm up before the Prelude")
    XCTAssertEqual(final.plannedDurationSecs, 300)
    XCTAssertNotNil(final.plannedDurationDisplay)
    XCTAssertEqual(final.groupId, groupId)
    XCTAssertEqual(final.plannedVariationId, variantId)
    XCTAssertEqual(final.plannedRepTarget, 3)
    XCTAssertEqual(final.scoreSummary, 6, "one play's mark is the whole entry's")

    XCTAssertEqual(final.plays.count, 1, "one stretch of practice, never switched")
    let play = try XCTUnwrap(final.plays.last)
    XCTAssertEqual(play.id, playId)
    XCTAssertEqual(play.variationId, variantId, "the plan seeds the play it opens")
    XCTAssertEqual(play.variationLabel, "Slow")
    XCTAssertFalse(play.durationDisplay.isEmpty)
    XCTAssertEqual(play.score, 6)
    XCTAssertEqual(play.repTarget, 3)
    XCTAssertEqual(play.repCount, 3, "missed then three got-its: 0, 1, 2, 3")
    XCTAssertEqual(play.repTargetReached, true)
    let history = try XCTUnwrap(play.repHistory)
    XCTAssertEqual(history.map(\.action), [.missed, .success, .success, .success])
    XCTAssertEqual(play.achievedTempo, 88, "176 quavers halves to 88 crotchets")
    XCTAssertEqual(play.clickPattern, click)
  }

  /// Real-bridge cross-domain round trip (#846, #1083): a session-side score,
  /// attributed to a ladder step via `SetEntryVariant` + `UpdateEntryScore`,
  /// must reappear as that step's `VariantView.latestScore` / `scoreHistory` /
  /// `isSolid` once the session is saved, a derivation that crosses BOTH the
  /// session and item domains, so a wire break in either side can hide behind
  /// the other's fields looking fine.
  func testRealBridgeVariantScoreAggregatesIntoLadderView() throws {
    let bridge = LiveBridge()
    _ = try bridge.update(.startApp)
    _ = try bridge.update(
      .item(
        .add(
          CreateItem(
            title: "Hanon No. 1", kind: .exercise, composer: nil, key: nil, modality: nil,
            tempo: nil, notes: nil, tags: [], photoId: nil))))
    let itemId = try XCTUnwrap(try bridge.view().items.first?.id)
    _ = try bridge.update(.item(.addVariant(itemId: itemId, label: "Slow")))
    _ = try bridge.update(.item(.addVariant(itemId: itemId, label: "Fast")))
    let ladder = try XCTUnwrap(try bridge.view().items.first?.variants)
    let slowId = try XCTUnwrap(ladder.first { $0.label == "Slow" }?.id)
    let fastId = try XCTUnwrap(ladder.first { $0.label == "Fast" }?.id)

    _ = try bridge.update(.session(.startBuilding))
    _ = try bridge.update(.session(.addToSetlist(itemId: itemId)))
    let entryId = try XCTUnwrap(try bridge.view().buildingSetlist?.entries.first?.id)
    _ = try bridge.update(.session(.setEntryVariant(entryId: entryId, variantId: slowId)))
    _ = try bridge.update(.session(.startSession(now: "2026-09-04T09:00:00Z")))
    _ = try bridge.update(.session(.nextItem(now: "2026-09-04T09:05:00Z")))
    let playId = try XCTUnwrap(try bridge.view().summary?.entries.first?.plays.last?.id)
    _ = try bridge.update(
      .session(.updateEntryScore(entryId: entryId, playId: playId, score: 8)))
    _ = try bridge.update(.session(.saveSession(now: "2026-09-04T09:06:00Z")))

    let view = try bridge.view()
    XCTAssertNil(view.error, "the score, attribution and save must all decode cleanly (#846)")
    let item = try XCTUnwrap(view.items.first { $0.id == itemId })
    let slow = try XCTUnwrap(item.variants.first { $0.id == slowId })
    let fast = try XCTUnwrap(item.variants.first { $0.id == fastId })

    XCTAssertEqual(slow.latestScore, 8, "the score attributed to Slow must land on Slow, not Fast")
    let historyEntry = try XCTUnwrap(slow.scoreHistory.first)
    XCTAssertEqual(historyEntry.score, 8)
    XCTAssertFalse(historyEntry.sessionId.isEmpty)
    XCTAssertNotNil(SessionClock.parseRFC3339(historyEntry.sessionDate))
    XCTAssertTrue(slow.isSolid, "8 of 10 reaches SOLID_SCORE_MIN")

    XCTAssertNil(fast.latestScore, "Fast was never practised")
    XCTAssertTrue(fast.scoreHistory.isEmpty)
    XCTAssertFalse(fast.isSolid)
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Resume on the bridge's `resolve` callback, not a wall-clock `fulfillment`:
  /// a loaded CI runner starves the detached recognition Task and a tight
  /// ceiling flakes (#956, #861). The 30s net is a backstop, not the happy path.
  private func whenResolved(
    _ bridge: FakeBridge, _ action: () -> Void,
    file: StaticString = #filePath, line: UInt = #line
  ) async {
    let gate = ResolveGate()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      let timeout = Task {
        try? await Task.sleep(for: .seconds(30))
        if gate.claim() {
          XCTFail("bridge never resolved within the 30s safety ceiling", file: file, line: line)
          continuation.resume()
        }
      }
      bridge.onResolve = {
        if gate.claim() {
          timeout.cancel()
          continuation.resume()
        }
      }
      action()
    }
  }

  static let sampleItem = Item(
    id: "p1", title: "Etude", kind: .piece, composer: "Chopin", key: nil, modality: nil,
    tempo: nil,
    notes: nil, tags: [], linkedExerciseIds: [], createdAt: "2026-01-01T00:00:00Z",
    updatedAt: "2026-01-01T00:00:00Z", priority: false, chordChart: nil, variants: [], photoId: nil,
    metre: nil)

}

private func emptyViewModel() throws -> ViewModel {
  try ViewModel.bincodeDeserialize(input: [UInt8](CoreFfi().view()))
}

private final class FakeBridge: CoreBridge {
  var updateHandler: (Event) -> [Request] = { _ in [] }
  var resolveHandler: (UInt32) -> [Request] = { _ in [] }
  var nextViewModel: (() throws -> ViewModel)?
  var onResolve: (() -> Void)?
  /// When set, the corresponding bridge call throws — drives the Store's
  /// `guarded` failure-soft path.
  var throwOnUpdate: Error?
  var throwOnView: Error?

  private(set) var events: [Event] = []
  private(set) var persistenceResolved: [(id: UInt32, output: PersistenceOutput)] = []
  private(set) var recognitionResolved: [(id: UInt32, output: RecognitionOutput)] = []
  private(set) var emptyResolved: [UInt32] = []
  private(set) var viewCallCount = 0

  func update(_ event: Event) throws -> [Request] {
    events.append(event)
    if let throwOnUpdate { throw throwOnUpdate }
    return updateHandler(event)
  }

  func resolve(_ id: UInt32, persistenceOutput: PersistenceOutput) throws -> [Request] {
    persistenceResolved.append((id, persistenceOutput))
    onResolve?()
    return resolveHandler(id)
  }

  func resolve(_ id: UInt32, recognitionOutput: RecognitionOutput) throws -> [Request] {
    recognitionResolved.append((id, recognitionOutput))
    onResolve?()
    return []
  }

  func resolveEmpty(_ id: UInt32) throws -> [Request] {
    emptyResolved.append(id)
    return []
  }

  func view() throws -> ViewModel {
    viewCallCount += 1
    if let throwOnView { throw throwOnView }
    if let nextViewModel { return try nextViewModel() }
    return try emptyViewModel()
  }
}

/// One-shot: only the first of {resolve, timeout} resumes (double-resume traps).
private final class ResolveGate {
  private let lock = NSLock()
  private var claimed = false
  func claim() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    if claimed { return false }
    claimed = true
    return true
  }
}

private struct TestError: Error {}

/// An `ItemStore` that always throws — drives the failure path (#816).
private struct FailingStore: ItemStore {
  func loadItems() throws -> [Item] { throw TestError() }
  func save(_ item: Item) throws { throw TestError() }
  func save(_ items: [Item]) throws { throw TestError() }
  func delete(id: String, deletedAt: String) throws { throw TestError() }
  func loadSessions() throws -> [PracticeSession] { throw TestError() }
  func saveSession(_ session: PracticeSession) throws { throw TestError() }
}
