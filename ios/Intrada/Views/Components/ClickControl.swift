import SwiftUI

/// The Focus Player's metronome row. The steppers exist only while the click
/// sounds, so configuration stays one layer down (design-principles T14, T2).
struct ClickControl: View {
  let bpm: Int
  /// The metre's beat value: the readout says `♪ = 168` in 7/8, never `♩`.
  var unit: UInt8 = 4
  let isRunning: Bool
  let unavailable: Bool
  /// False once `bpm` is stepped off what the item seeded: the row then reads as
  /// the click, so stopping never advertises a tempo the next tap would not play.
  let atSeededTempo: Bool
  /// The item's declared tempo. Nil when the row names the click instead.
  let targetDisplay: String?
  let targetSpoken: String?
  let onToggle: () -> Void
  let onStep: (Int) -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.marker) private var marker

  var body: some View {
    HStack(spacing: IntradaSpacing.controlGap) {
      if isRunning {
        TempoStepButton(systemImage: "minus", label: "Slower") { onStep(-TempoScale.step) }
          .transition(.opacity)
      }
      toggle
      if isRunning {
        TempoStepButton(systemImage: "plus", label: "Faster") { onStep(TempoScale.step) }
          .transition(.opacity)
      }
    }
    .animation(reduceMotion ? nil : IntradaMotion.snappy, value: isRunning)
  }

  private var toggle: some View {
    Button {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      onToggle()
    } label: {
      Label(readout, systemImage: "metronome")
        .font(IntradaFont.bodyMedium)
        .monospacedDigit()
        // "♩ = 208" is one notation token; at the largest text sizes it wraps
        // between the glyph and the number, which reads as two facts.
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .foregroundStyle(tint)
        .padding(.horizontal, IntradaSpacing.cardCompact)
        .frame(minHeight: 44)
        .background(isRunning ? marker : .clear, in: Capsule())
    }
    .buttonStyle(PressRebound())
    .accessibilityLabel(isRunning ? "Stop the click" : "Start the click")
    .accessibilityValue(spokenValue)
  }

  var readout: String {
    if unavailable { return "Click unavailable" }
    if isRunning || !atSeededTempo { return TempoUnit.readout(bpm, unit: unit) }
    return targetDisplay ?? "Click"
  }

  private var tint: Color {
    if unavailable { return IntradaColor.danger }
    return isRunning ? IntradaColor.accent : IntradaColor.inkSecondary
  }

  // VoiceOver never hears the ♩ glyph, so the bpm is spelled out.
  var spokenValue: String {
    if unavailable { return "unavailable" }
    if isRunning || !atSeededTempo { return TempoUnit.spoken(bpm, unit: unit) }
    return targetSpoken ?? "no tempo set"
  }
}

#if DEBUG
  #Preview("Click control") {
    VStack(spacing: 32) {
      ClickControl(
        bpm: 66, isRunning: false, unavailable: false, atSeededTempo: true,
        targetDisplay: "Andante · ♩ = 66", targetSpoken: "Andante, 66 beats per minute",
        onToggle: {}, onStep: { _ in })
      ClickControl(
        bpm: 72, isRunning: true, unavailable: false, atSeededTempo: false,
        targetDisplay: "Andante · ♩ = 66", targetSpoken: "Andante, 66 beats per minute",
        onToggle: {}, onStep: { _ in })
      ClickControl(
        bpm: 96, isRunning: false, unavailable: false, atSeededTempo: true,
        targetDisplay: nil, targetSpoken: nil, onToggle: {}, onStep: { _ in })
      ClickControl(
        bpm: 96, isRunning: false, unavailable: true, atSeededTempo: true,
        targetDisplay: nil, targetSpoken: nil, onToggle: {}, onStep: { _ in })
    }
    .padding()
    .background(RadialGradient.playerPaper)
  }
#endif
