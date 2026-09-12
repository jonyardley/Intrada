import SharedTypes
import SwiftUI

/// A tempo and whether the user set it, as one value: `bpm` is not writable
/// except through `set`, so the sheet cannot report a number without also
/// reporting where it came from (#1420).
@MainActor
struct TrackedTempo {
  private(set) var bpm: Int
  private(set) var userSet = false
  /// The beat value `bpm` counts in, so a quaver tempo is not clamped against
  /// the crotchet band (#1499).
  private let unit: UInt8

  init(startingBpm: Int, unit: UInt8 = 4) {
    self.unit = unit
    bpm = TempoScale.clamp(startingBpm, unit: unit)
  }

  mutating func set(_ next: Int) {
    bpm = TempoScale.clamp(next, unit: unit)
    userSet = true
  }
}

/// One row of the sheet: a stretch of the item spent on one variation, already
/// resolved for display so the sheet stays free of core types (#1739).
struct ReflectionPlay: Identifiable, Equatable {
  let id: String
  /// The variation's label, or `nil` for an unattributed play (a piece, or an
  /// exercise with no variations).
  let variationLabel: String?
  let durationDisplay: String
  let repCount: UInt8?
  let repTarget: UInt8?

  var title: String { variationLabel ?? "No variation" }

  var meta: String {
    var parts = [durationDisplay]
    if let repTarget { parts.append("\(repCount ?? 0) of \(repTarget)") }
    return parts.joined(separator: " · ")
  }

  /// The sheet's rows for one entry. The open play's own seconds are only
  /// stamped when the core closes it, so its share of the item's elapsed time
  /// is what the closed plays have not already claimed.
  static func rows(_ plays: [VariationPlayView], elapsed: Int) -> [ReflectionPlay] {
    let closed = plays.dropLast().reduce(0) { $0 + Int($1.seconds) }
    return plays.enumerated().map { index, play in
      let isOpen = index == plays.count - 1
      let seconds = isOpen ? max(elapsed - closed, 0) : Int(play.seconds)
      return ReflectionPlay(
        id: play.id, variationLabel: play.variationLabel,
        durationDisplay: SessionClock.clockDisplay(seconds),
        repCount: play.repCount, repTarget: play.repTarget)
    }
  }
}

/// What the sheet collected. `tempoUserSet` is an observation, not a
/// judgement: whether it amounts to evidence is the core's ruling (#1420).
struct ReflectionResult {
  /// Play id to mark, holding only the rows the musician actually marked.
  let marks: [String: UInt8]
  let note: String
  let achievedTempo: UInt16
  /// The user moved the stepper rather than accepting the pre-fill.
  let tempoUserSet: Bool
}

struct ReflectionSheet: View {
  let itemTitle: String
  let elapsedDisplay: String
  /// The item's own declared tempo marking (the practice target), if any.
  let tempoTarget: UInt16?
  /// The beat value the click counted in, so the stepper reads `♪` when the
  /// player did (#1499).
  let tempoUnit: UInt8
  /// What was played, in order. One row is the sheet that shipped before
  /// plays existed; several give each variation its own mark (#1739
  /// decision 10).
  let plays: [ReflectionPlay]
  let onSave: (ReflectionResult) -> Void
  let onSkip: () -> Void

  @State private var marks: [String: Int] = [:]
  @State private var note: String = ""
  @State private var achievedTempo: TrackedTempo

  init(
    itemTitle: String, elapsedDisplay: String, tempoTarget: UInt16?,
    startingTempoBpm: Int = TempoScale.defaultBpm, tempoUnit: UInt8 = 4,
    plays: [ReflectionPlay],
    onSave: @escaping (ReflectionResult) -> Void,
    onSkip: @escaping () -> Void
  ) {
    self.itemTitle = itemTitle
    self.elapsedDisplay = elapsedDisplay
    self.tempoTarget = tempoTarget
    self.tempoUnit = tempoUnit
    self.plays = plays
    self.onSave = onSave
    self.onSkip = onSkip
    _achievedTempo = State(
      initialValue: TrackedTempo(startingBpm: startingTempoBpm, unit: tempoUnit))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        VStack(spacing: 8) {
          Text("Item complete · \(elapsedDisplay)")
            .font(IntradaFont.badge).textCase(.uppercase).kerning(1.5)
            .foregroundStyle(IntradaColor.exerciseBadgeFg)
          Text("How did \(itemTitle) go?")
            .font(IntradaFont.pageTitle(24)).foregroundStyle(IntradaColor.ink)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, IntradaSpacing.card)

        if plays.count > 1 {
          eyebrow("What you played").padding(.top, IntradaSpacing.section)
          playRows.padding(.top, IntradaSpacing.controlGap)
        } else if let only = plays.first {
          // No mark control without a play to write it to: the core gives every
          // practised entry at least one, so an empty list means something is
          // wrong, and ten tappable buttons that record nothing would hide it.
          eyebrow("Mark").padding(.top, IntradaSpacing.section)
          ScoreSelector(
            score: mark(for: only.id), accessibilityLabel: "Mark for \(itemTitle)"
          ) { next in
            setMark(next, for: only.id)
          }
          .padding(.top, IntradaSpacing.controlGap)
        }

        eyebrow(tempoEyebrow).padding(.top, IntradaSpacing.card)
        TempoStepper(value: achievedTempoBinding, unit: tempoUnit)
          .padding(.top, IntradaSpacing.controlGap)

        eyebrow("Reflection · optional").padding(.top, IntradaSpacing.card)
        TextField("What went well? What to fix next time?", text: $note, axis: .vertical)
          .lineLimit(3...5)
          .font(IntradaFont.field)
          .foregroundStyle(IntradaColor.ink)
          .padding(IntradaSpacing.cardCompact)
          .cardSurface(cornerRadius: IntradaRadius.control)
          .padding(.top, IntradaSpacing.controlGap)

        BrandBarButton {
          onSave(
            ReflectionResult(
              marks: marks.compactMapValues { $0 == 0 ? nil : UInt8($0) },
              note: note.trimmingCharacters(in: .whitespacesAndNewlines),
              achievedTempo: UInt16(achievedTempo.bpm),
              tempoUserSet: achievedTempo.userSet))
        } label: {
          Text("Save & continue")
          Image(systemName: "arrow.right")
        }
        .padding(.top, IntradaSpacing.card)

        Button("Skip rating") { onSkip() }
          .font(IntradaFont.bodyMedium)
          .foregroundStyle(IntradaColor.inkSecondary)
          .frame(maxWidth: .infinity)
          .padding(.top, IntradaSpacing.cardCompact)
      }
      .padding(.horizontal, IntradaSpacing.section)
      .padding(.bottom, IntradaSpacing.section)
    }
  }

  private var playRows: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(plays.enumerated()), id: \.element.id) { index, play in
        if index > 0 { HairlineDivider() }
        VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
          HStack(alignment: .firstTextBaseline, spacing: IntradaSpacing.cardCompact) {
            Text(play.title)
              .font(IntradaFont.bodyMedium)
              .foregroundStyle(IntradaColor.ink)
              .frame(maxWidth: .infinity, alignment: .leading)
            Text(play.meta)
              .font(IntradaFont.meta)
              .foregroundStyle(IntradaColor.inkSecondary)
          }
          ScoreSelector(
            score: mark(for: play.id), accessibilityLabel: "Mark for \(play.title)"
          ) { next in
            setMark(next, for: play.id)
          }
        }
        .padding(.vertical, IntradaSpacing.cardCompact)
      }
    }
  }

  // Named with the variation it lands on once there is more than one row: the
  // click was sounding for the last stretch, so that is the only play its
  // reading is evidence for (T16).
  private var tempoEyebrow: String {
    if plays.count > 1, let label = plays.last?.variationLabel {
      return "Tempo reached · \(label)"
    }
    return tempoTarget.map { "Tempo reached · target ♩ = \($0)" } ?? "Tempo reached"
  }

  private func mark(for playId: String) -> Int { marks[playId] ?? 0 }

  private func setMark(_ next: UInt8?, for playId: String) {
    marks[playId] = next.map(Int.init) ?? 0
  }

  // TempoStepper only writes on an explicit tap or accessibility adjustment,
  // never on appear, so a write here is the user considering the number (#1420).
  private var achievedTempoBinding: Binding<Int> {
    Binding(get: { achievedTempo.bpm }, set: { achievedTempo.set($0) })
  }

  private func eyebrow(_ text: String) -> some View {
    Text(text)
      .font(IntradaFont.eyebrow).textCase(.uppercase).kerning(1.2)
      .foregroundStyle(IntradaColor.inkFaint)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

#if DEBUG
  #Preview("Reflection · one play") {
    Color.black.opacity(0.2).ignoresSafeArea()
      .sheet(isPresented: .constant(true)) {
        ReflectionSheet(
          itemTitle: "Clair de Lune", elapsedDisplay: "7:00", tempoTarget: 66,
          plays: [ReflectionPlay.preview("p1", nil, "7:00", nil, nil)],
          onSave: { _ in }, onSkip: {}
        )
        .presentationDetents([.medium, .large])
      }
  }

  #Preview("Reflection · three variations") {
    Color.black.opacity(0.2).ignoresSafeArea()
      .sheet(isPresented: .constant(true)) {
        ReflectionSheet(
          itemTitle: "Major Scales", elapsedDisplay: "12:40", tempoTarget: nil,
          plays: [
            ReflectionPlay.preview("p1", "C major", "4:10", 8, 10),
            ReflectionPlay.preview("p2", "G major", "3:20", 10, 10),
            ReflectionPlay.preview("p3", "D major", "5:10", 4, 10),
          ],
          onSave: { _ in }, onSkip: {}
        )
        .presentationDetents([.large])
      }
  }
#endif
