import SharedTypes
import SwiftUI

/// Field state for the add/edit item form, shared by `LibraryAddScreen` and
/// `LibraryEditScreen`. The shell only collects values; the core validates.
@Observable
final class ItemFormModel {
  /// The fields a photographed page can fill (#1436). Key and notes are not
  /// among them: nothing on a page reliably says either.
  /// `chart` is always empty until phase D of `specs/piece-from-photo.md`.
  enum ReadField: Hashable {
    case title, composer, marking, bpm, chart
  }

  var kind: ItemKind
  var key = ""
  var modality: Modality?
  var formError: String?
  /// Where the core said the refused save failed, until the thing it points at
  /// changes (#1595). The banner keeps its sentence either way.
  var errorTarget: FormErrorTarget?
  /// The page the fields were read off, carried onto the piece the form
  /// creates so it is not photographed a second time (#1436).
  var photoId: String?

  /// Which fields still hold what the photo was read into, and whether that
  /// read was weak. Typing takes a field off: it is the user's from that
  /// keystroke on, so it must stop claiming to be the page's.
  private(set) var readFrom: [ReadField: Bool] = [:]

  // Written through `edited` so the mark clears on the keystroke, not on
  // submit; `fill(from:)` sets the storage directly.
  var title: String {
    get { storedTitle }
    set {
      storedTitle = newValue
      edited(.title)
    }
  }
  var composer: String {
    get { storedComposer }
    set {
      storedComposer = newValue
      edited(.composer)
    }
  }
  var marking: String {
    get { storedMarking }
    set {
      storedMarking = newValue
      edited(.marking)
    }
  }
  var bpm: String {
    get { storedBpm }
    set {
      storedBpm = newValue
      edited(.bpm)
    }
  }
  var chartText: String {
    get { storedChart }
    set {
      storedChart = newValue
      edited(.chart)
    }
  }
  var notes: String {
    get { storedNotes }
    set {
      storedNotes = newValue
      cleared(.notes)
    }
  }
  var tags: [String] {
    get { storedTags }
    set {
      storedTags = newValue
      cleared(.tags)
    }
  }

  /// Removing or re-choosing a row rewrites the list the core numbered, so a
  /// mark on any row cannot survive it (spec decision 12).
  var stagedExercises: [StagedExercise] = [] {
    didSet {
      if case .exercise = errorTarget { errorTarget = nil }
    }
  }

  private var storedTitle = ""
  private var storedComposer = ""
  private var storedMarking = ""
  private var storedBpm = ""
  private var storedChart = ""
  private var storedNotes = ""
  private var storedTags: [String] = []

  init(kind: ItemKind = .piece) {
    self.kind = kind
  }

  init(item: LibraryItemView) {
    kind = item.itemType
    storedTitle = item.title
    storedComposer = item.subtitle
    tags = item.tags
    // Normalise on load so editing self-heals legacy combined values
    // ("F# major") into tonic + modality even if the user never re-taps a spoke.
    let selection = KeyHelper.selection(key: item.key ?? "", modality: item.modality)
    key = selection?.spelling ?? item.key ?? ""
    modality = selection?.mode ?? item.modality
    storedMarking = item.tempoMarking ?? ""
    storedBpm = item.tempoBpm.map(String.init) ?? ""
    notes = item.notes ?? ""
  }

  /// A field is written when empty, or when it still holds an earlier read:
  /// what the user typed is theirs, but a second scan must replace what the
  /// first one wrote, and `isEmpty` alone cannot tell those apart.
  /// Nothing here is saved; pressing Add is what writes.
  func fill(from draft: PhotoDraft) {
    func take(_ field: ReadField, _ value: String, weak: Bool, into store: (String) -> Void) {
      store(value)
      readFrom[field] = weak
    }

    if let read = draft.title, replaceable(.title, storedTitle) {
      take(.title, read.value, weak: read.weak) { storedTitle = $0 }
    }
    if let read = draft.composer, replaceable(.composer, storedComposer) {
      take(.composer, read.value, weak: read.weak) { storedComposer = $0 }
    }
    if let read = draft.tempo {
      if let marking = read.value.marking, replaceable(.marking, storedMarking) {
        take(.marking, marking, weak: read.weak) { storedMarking = $0 }
      }
      if let beats = read.value.bpm, replaceable(.bpm, storedBpm) {
        take(.bpm, String(beats), weak: read.weak) { storedBpm = $0 }
      }
    }
    if let read = draft.chartText, replaceable(.chart, storedChart) {
      take(.chart, read.value, weak: read.weak) { storedChart = $0 }
    }
  }

  private func replaceable(_ field: ReadField, _ current: String) -> Bool {
    current.isEmpty || readFrom[field] != nil
  }

  private func edited(_ field: ReadField) {
    readFrom[field] = nil
    switch field {
    case .title: cleared(.title)
    case .composer: cleared(.composer)
    case .marking, .bpm: cleared(.tempo)
    case .chart: if faultsChart { errorTarget = nil }
    }
  }

  private func cleared(_ field: FormErrorField) {
    guard case .piece(let marked) = errorTarget, marked == field else { return }
    errorTarget = nil
  }

  // ── What the mark is on ──

  func faults(_ field: FormErrorField) -> Bool {
    guard case .piece(let marked) = errorTarget else { return false }
    return marked == field
  }

  var faultsChart: Bool {
    switch errorTarget {
    case .chart, .chartBar: true
    default: false
    }
  }

  var faultedBarNumber: UInt64? {
    guard case .chartBar(let bar, _) = errorTarget else { return nil }
    return bar
  }

  func faults(row index: Int) -> Bool {
    guard case .exercise(let marked, _) = errorTarget else { return false }
    return marked == UInt64(index)
  }

  func faultedField(row index: Int) -> FormErrorField? {
    guard case .exercise(let marked, let field) = errorTarget, marked == UInt64(index) else {
      return nil
    }
    return field
  }

  var canSubmit: Bool {
    !title.trimmingCharacters(in: .whitespaces).isEmpty
  }

  func createInput() -> CreateItem {
    CreateItem(
      title: title.trimmingCharacters(in: .whitespacesAndNewlines),
      kind: kind,
      composer: emptyToNil(composer),
      key: emptyToNil(key),
      modality: modality,
      tempo: buildTempo(),
      notes: emptyToNil(notes),
      tags: tags,
      photoId: photoId)
  }

  var hasStagedExtras: Bool {
    !stagedExercises.isEmpty || emptyToNil(chartText) != nil
  }

  func scaffoldEntries() -> [ScaffoldEntry] {
    stagedExercises.map(\.entry)
  }

  func updateInput() -> UpdateItem {
    UpdateItem(
      title: title,
      kind: kind,
      composer: .some(emptyToNil(composer)),
      key: .some(emptyToNil(key)),
      modality: .some(modality),
      tempo: .some(buildTempo()),
      notes: .some(emptyToNil(notes)),
      tags: tags,
      priority: nil)
  }

  private func emptyToNil(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func buildTempo() -> Tempo? {
    let mark = emptyToNil(marking)
    let beats = UInt16(bpm.trimmingCharacters(in: .whitespaces))
    if mark == nil && beats == nil { return nil }
    return Tempo(marking: mark, bpm: beats)
  }
}

enum StagedExercise: Identifiable, Hashable {
  case draft(id: UUID, title: String, key: String, modality: Modality?, bpm: String)
  case existing(id: String, title: String, meta: String?)

  var id: String {
    switch self {
    case .draft(let id, _, _, _, _): id.uuidString
    case .existing(let id, _, _): id
    }
  }

  var existingId: String? {
    switch self {
    case .draft: nil
    case .existing(let id, _, _): id
    }
  }

  var title: String {
    switch self {
    case .draft(_, let title, _, _, _): title
    case .existing(_, let title, _): title
    }
  }

  var meta: String? {
    switch self {
    case .draft(_, _, let key, let modality, let bpm):
      let mode = modality == .minor ? "minor" : "major"
      let parts = [
        key.isEmpty ? nil : "\(key) \(mode)",
        bpm.isEmpty ? nil : "\(bpm) bpm",
      ].compactMap { $0 }
      return parts.isEmpty ? nil : parts.joined(separator: " · ")
    case .existing(_, _, let meta): return meta
    }
  }

  var entry: ScaffoldEntry {
    switch self {
    // Trimmed here rather than relying on the sheet to have done it, so the
    // tempo survives whoever builds the case.
    case .draft(_, let title, let key, let modality, let bpm):
      .new(
        CreateItem(
          title: title.trimmingCharacters(in: .whitespacesAndNewlines),
          kind: .exercise,
          composer: nil,
          key: key.isEmpty ? nil : key,
          modality: modality,
          tempo: UInt16(bpm.trimmingCharacters(in: .whitespaces)).map {
            Tempo(marking: nil, bpm: $0)
          },
          notes: nil,
          tags: [],
          photoId: nil))
    case .existing(let id, _, _):
      .existing(id: id)
    }
  }
}
