import SharedTypes
import SwiftUI

/// Two layers down from the tempo row (T19): the time signature, offered with
/// the piece's answer already in it, and which beats of the bar sound. Both
/// hold for this session only; the piece keeps its own metre.
struct ClickSheet: View {
  let click: ClickController
  let bpm: Int

  @State private var choice: MetreChoice
  @State private var beats: Int
  @State private var unit: UInt8
  @State private var grouping: [UInt8]?

  private static let presets: [Metre] = [
    Metre(beats: 3, unit: 4, groups: nil),
    Metre(beats: 4, unit: 4, groups: nil),
    Metre(beats: 6, unit: 8, groups: [3, 3]),
  ]

  enum MetreChoice: Hashable {
    case metre(Metre)
    case other
  }

  init(click: ClickController, bpm: Int) {
    self.click = click
    self.bpm = bpm
    let metre = click.metre
    _choice = State(initialValue: Self.presets.contains(metre) ? .metre(metre) : .other)
    _beats = State(initialValue: Int(metre.beats))
    _unit = State(initialValue: metre.unit)
    _grouping = State(initialValue: metre.groups)
  }

  var body: some View {
    BottomSheet(title: "Metronome", detents: [.medium, .large]) {
      ScrollView {
        VStack(alignment: .leading, spacing: IntradaSpacing.section) {
          tempoNote
          metreSection
          if choice == .other {
            otherSection
          }
          soundsOnSection
        }
        .padding(IntradaSpacing.card)
      }
    }
  }

  private var tempoNote: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      Text(TempoUnit.readout(bpm, unit: click.metre.unit))
        .font(IntradaFont.scoreNumeral(24))
        .monospacedDigit()
        .foregroundStyle(IntradaColor.ink)
      Text(
        "The tempo stays as it is. The pattern changes which beats you hear, not how fast you play."
      )
      .font(IntradaFont.meta)
      .foregroundStyle(IntradaColor.inkSecondary)
    }
    .accessibilityElement(children: .combine)
  }

  private var metreChoices: [MetreChoice] {
    Self.presets.map(MetreChoice.metre) + [.other]
  }

  private var metreSection: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      Eyebrow("Time signature")
      SegmentedPills(
        options: metreChoices,
        selection: Binding(
          get: { choice },
          set: { next in
            choice = next
            if case .metre(let metre) = next {
              beats = Int(metre.beats)
              unit = metre.unit
              grouping = metre.groups
              click.setMetre(metre)
            }
          }),
        label: { choice in
          switch choice {
          case .metre(let metre): TempoUnit.metreLabel(metre)
          case .other: "Other"
          }
        },
        layout: .fullWidthTrack)
      Text("From the piece. Changing it here holds for this session only.")
        .font(IntradaFont.meta)
        .foregroundStyle(IntradaColor.inkSecondary)
    }
  }

  private var otherSection: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.row) {
      VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
        Eyebrow("Beats in the bar")
        Stepper(value: $beats, in: 2...12) {
          Text("\(beats)")
            .font(IntradaFont.scoreNumeral(24))
            .monospacedDigit()
            .foregroundStyle(IntradaColor.ink)
        }
        .onChange(of: beats) { _, _ in
          grouping = nil
          commitOther()
        }
      }
      VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
        Eyebrow("Beat value")
        SegmentedPills(
          options: [UInt8(2), 4, 8],
          selection: Binding(
            get: { unit },
            set: {
              unit = $0
              commitOther()
            }),
          label: { "\($0)" },
          hint: { TempoUnit.spokenName($0) },
          layout: .fullWidthTrack)
      }
      let groupings = Self.groupings(for: beats)
      if !groupings.isEmpty {
        VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
          Eyebrow("Grouped")
          SegmentedPills(
            options: [nil] + groupings.map(Optional.some),
            selection: Binding(
              get: { grouping },
              set: {
                grouping = $0
                commitOther()
              }),
            label: { $0.map { $0.map(String.init).joined(separator: " + ") } ?? "Not grouped" },
            layout: .fullWidthTrack)
        }
      }
    }
  }

  private func commitOther() {
    click.setMetre(Metre(beats: UInt8(beats), unit: unit, groups: grouping))
  }

  /// The groupings a musician would reach for; anything else stays ungrouped.
  /// Offered here, validated in the core.
  static func groupings(for beats: Int) -> [[UInt8]] {
    switch beats {
    case 5: [[3, 2], [2, 3]]
    case 6: [[3, 3], [2, 2, 2]]
    case 7: [[3, 2, 2], [2, 3, 2], [2, 2, 3]]
    case 8: [[3, 3, 2], [3, 2, 3], [2, 3, 3]]
    case 9: [[3, 3, 3], [2, 2, 2, 3]]
    case 10: [[3, 3, 2, 2], [2, 3, 2, 3]]
    case 11: [[3, 3, 3, 2], [2, 2, 3, 2, 2]]
    case 12: [[3, 3, 3, 3], [2, 2, 2, 2, 2, 2]]
    default: []
    }
  }

  private var soundsOnSection: some View {
    let metre = click.metre
    return VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      Eyebrow("Sounds on")
      // Optional option type so a hand-toggled mask matching no preset simply
      // selects nothing, as the grouping picker above does for "Not grouped".
      SegmentedPills(
        options: ClickPattern.offered(for: metre).map(Optional.some),
        selection: Binding(
          get: { ClickPattern.matching(click.sounding, in: metre) },
          set: { if let pattern = $0 { click.apply(pattern) } }),
        label: { $0?.title ?? "" },
        unselectedColor: IntradaColor.inkSecondary,
        layout: .fullWidthTrack)
      beatGrid(metre)
    }
  }

  /// One tap per beat, in rows: the metre's own groups when it declares them,
  /// so 3 + 2 + 2 reads as the shape of the bar, and otherwise split so that a
  /// twelve-beat bar still fits the sheet rather than running off its edge.
  private func beatGrid(_ metre: Metre) -> some View {
    let rows = Self.gridRows(metre)
    return VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      ForEach(rows.indices, id: \.self) { r in
        HStack(spacing: IntradaSpacing.controlGap) {
          ForEach(rows[r], id: \.self) { beat in
            let on = click.sounding & (1 << UInt16(beat)) != 0
            Button("\(beat + 1)") { click.toggleBeat(beat) }
              .buttonStyle(.plain)
              .font(IntradaFont.bodyMedium)
              .monospacedDigit()
              .foregroundStyle(on ? IntradaColor.onAccent : IntradaColor.inkSecondary)
              .frame(width: 44, height: 44)
              .background(
                on ? IntradaColor.accent : IntradaColor.cardFill,
                in: RoundedRectangle(cornerRadius: IntradaRadius.control)
              )
              .overlay(
                RoundedRectangle(cornerRadius: IntradaRadius.control)
                  .stroke(IntradaColor.hairline, lineWidth: on ? 0 : 1)
              )
              .accessibilityLabel("Beat \(beat + 1)")
              .accessibilityValue(on ? "sounds" : "silent")
              .accessibilityAddTraits(on ? .isSelected : [])
          }
        }
      }
    }
  }

  /// Six 44pt cells and their gaps are the widest row that fits an iPhone
  /// sheet, so an ungrouped bar longer than that is halved rather than clipped.
  static func gridRows(_ metre: Metre) -> [[Int]] {
    let beats = Int(metre.beats)
    let lengths: [Int] =
      beats > 6
      ? (metre.groups.map { $0.map(Int.init) } ?? [(beats + 1) / 2, beats / 2]) : [beats]
    var rows: [[Int]] = []
    var start = 0
    for length in lengths {
      rows.append(Array(start..<(start + length)))
      start += length
    }
    return rows
  }
}
