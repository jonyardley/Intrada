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

/// What the sheet collected. `tempoUserSet` is an observation, not a
/// judgement: whether it amounts to evidence is the core's ruling (#1420).
struct ReflectionResult {
  let score: UInt8?
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
  let onSave: (ReflectionResult) -> Void
  let onSkip: () -> Void

  @State private var score: Int = 0
  @State private var note: String = ""
  @State private var achievedTempo: TrackedTempo

  init(
    itemTitle: String, elapsedDisplay: String, tempoTarget: UInt16?,
    startingTempoBpm: Int = TempoScale.defaultBpm, tempoUnit: UInt8 = 4,
    onSave: @escaping (ReflectionResult) -> Void,
    onSkip: @escaping () -> Void
  ) {
    self.itemTitle = itemTitle
    self.elapsedDisplay = elapsedDisplay
    self.tempoTarget = tempoTarget
    self.tempoUnit = tempoUnit
    self.onSave = onSave
    self.onSkip = onSkip
    _achievedTempo = State(
      initialValue: TrackedTempo(startingBpm: startingTempoBpm, unit: tempoUnit))
  }

  var body: some View {
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

      eyebrow("Mark").padding(.top, IntradaSpacing.section)
      ScoreSelector(score: score, accessibilityLabel: "Mark for \(itemTitle)") { next in
        score = next.map(Int.init) ?? 0
      }
      .padding(.top, IntradaSpacing.controlGap)

      eyebrow(tempoTarget.map { "Tempo reached · target ♩ = \($0)" } ?? "Tempo reached")
        .padding(.top, IntradaSpacing.card)
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
            score: score == 0 ? nil : UInt8(score),
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
  #Preview("Reflection") {
    Color.black.opacity(0.2).ignoresSafeArea()
      .sheet(isPresented: .constant(true)) {
        ReflectionSheet(
          itemTitle: "Scales · D♭", elapsedDisplay: "7:00", tempoTarget: nil,
          onSave: { _ in }, onSkip: {}
        )
        .presentationDetents([.medium, .large])
      }
  }

  #Preview("Reflection · with tempo target") {
    Color.black.opacity(0.2).ignoresSafeArea()
      .sheet(isPresented: .constant(true)) {
        ReflectionSheet(
          itemTitle: "Scales · D♭", elapsedDisplay: "7:00", tempoTarget: 96,
          onSave: { _ in }, onSkip: {}
        )
        .presentationDetents([.medium, .large])
      }
  }
#endif
