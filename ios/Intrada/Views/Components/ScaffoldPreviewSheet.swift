import SharedTypes
import SwiftUI

/// The exercises worked out from a piece's chord chart, as a selectable commit
/// sheet (chart-to-scaffold Phase B). Offered as suggestions, not a syllabus
/// (T18). The core derives; this only renders and
/// hands back the ticked `kind`s — the core re-derives and materialises them,
/// so no spec content crosses the wire (#1106). Already-linked specs are shown
/// but not selectable (dedup); "Add N" commits the rest.
struct ScaffoldPreviewSheet: View {
  let preview: ScaffoldPreviewView
  let onCommit: (Swift.Set<ScaffoldKind>) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var selected: Swift.Set<ScaffoldKind>

  init(preview: ScaffoldPreviewView, onCommit: @escaping (Swift.Set<ScaffoldKind>) -> Void) {
    self.preview = preview
    self.onCommit = onCommit
    // Pre-tick everything not already linked — the common case is "add them all".
    _selected = State(
      initialValue: Swift.Set(preview.specs.filter { !$0.alreadyLinked }.map(\.kind)))
  }

  var body: some View {
    BottomSheet(
      title: "From the chord chart",
      confirmationLabel: confirmationLabel,
      confirmationDisabled: selected.isEmpty,
      onDone: { onCommit(selected) },
      leadingAction: { Button("Cancel") { dismiss() } },
      content: {
        ScrollView {
          VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
            header
            VStack(spacing: 0) {
              ForEach(Array(preview.specs.enumerated()), id: \.offset) { index, spec in
                if index > 0 {
                  HairlineDivider()
                }
                specRow(spec)
              }
            }
            .cardSurface()
            if preview.fallbackTotal > 0 {
              fallbackLegend
            }
          }
          .padding(IntradaSpacing.card)
        }
      })
  }

  private var confirmationLabel: String {
    selected.isEmpty ? "Add" : "Add \(selected.count)"
  }

  private var header: some View {
    HStack(spacing: 6) {
      Image(systemName: "key")
        .font(IntradaFont.meta)
        .foregroundStyle(IntradaColor.exerciseBadgeFg)
        .accessibilityHidden(true)
      Text("Worked out from these changes, in \(preview.key)")
        .font(IntradaFont.meta)
        .foregroundStyle(IntradaColor.inkSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Worked out from these changes, in \(preview.key), \(preview.specs.count) exercises")
  }

  @ViewBuilder private func specRow(_ spec: ScaffoldSpecView) -> some View {
    if spec.alreadyLinked {
      SpecRow(spec: spec, isOn: false, selectable: false)
    } else {
      let isOn = selected.contains(spec.kind)
      Button {
        toggle(spec.kind, isOn: isOn)
      } label: {
        SpecRow(spec: spec, isOn: isOn, selectable: true)
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
  }

  private func toggle(_ kind: ScaffoldKind, isOn: Bool) {
    if isOn {
      selected.remove(kind)
    } else {
      selected.insert(kind)
    }
    UISelectionFeedbackGenerator().selectionChanged()
  }

  private var fallbackLegend: some View {
    HStack(alignment: .top, spacing: 6) {
      Image(systemName: "arrow.turn.down.right")
        .font(IntradaFont.micro)
        .foregroundStyle(IntradaColor.exerciseBadgeFg)
        .accessibilityHidden(true)
      Text("Fallback flags a change mapped to its arpeggio, not a scale.")
        .font(IntradaFont.micro)
        .foregroundStyle(IntradaColor.inkFaint)
    }
    .padding(.horizontal, IntradaSpacing.controlGap)
  }
}

private struct SpecRow: View {
  let spec: ScaffoldSpecView
  let isOn: Bool
  let selectable: Bool

  var body: some View {
    HStack(spacing: IntradaSpacing.row) {
      ItemKind.exercise.bar
        .frame(width: 4, height: 34)
        .clipShape(Capsule())
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: IntradaSpacing.controlGap) {
          Text(spec.title)
            .font(IntradaFont.cardTitle())
            .foregroundStyle(IntradaColor.ink)
          if spec.alreadyLinked {
            FlagBadge(text: "Already added", tint: IntradaColor.inkSecondary)
          }
          if spec.fallback {
            FlagBadge(text: "Fallback", tint: IntradaColor.exerciseBadgeFg)
          }
        }
        Text(spec.rationale)
          .font(IntradaFont.meta)
          .foregroundStyle(IntradaColor.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if selectable {
        membershipControl(isOn: isOn)
      }
    }
    .padding(.vertical, IntradaSpacing.row)
    .padding(.leading, 20)
    .padding(.trailing, IntradaSpacing.card)
    .background(IntradaColor.cardFill)
    .contentShape(Rectangle())
    .opacity(selectable ? 1 : 0.6)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  private func membershipControl(isOn: Bool) -> some View {
    ZStack {
      Circle()
        .fill(isOn ? AnyShapeStyle(IntradaColor.accent) : AnyShapeStyle(Color.clear))
        .overlay(
          Circle()
            .strokeBorder(IntradaColor.accent, lineWidth: 2)
            .opacity(isOn ? 0 : 1))
      Image(systemName: isOn ? "checkmark" : "plus")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(isOn ? IntradaColor.onAccent : IntradaColor.accent)
    }
    .frame(width: 28, height: 28)
  }

  private var accessibilityLabel: String {
    var parts = [spec.title, spec.rationale]
    if spec.alreadyLinked {
      parts.append("already added")
    } else {
      parts.append(isOn ? "selected, tap to remove" : "not selected, tap to add")
    }
    if spec.fallback { parts.append("uses an arpeggio fallback") }
    return parts.joined(separator: ", ")
  }
}

private struct FlagBadge: View {
  let text: String
  let tint: Color

  var body: some View {
    Text(text)
      .font(IntradaFont.micro)
      .textCase(.uppercase)
      .kerning(0.4)
      .foregroundStyle(tint)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(IntradaColor.surfaceSunken, in: Capsule())
      .accessibilityHidden(true)
  }
}

#if DEBUG
  #Preview("From the chord chart") {
    Color.clear.sheet(isPresented: .constant(true)) {
      ScaffoldPreviewSheet(preview: .preview, onCommit: { _ in })
    }
  }

  extension ScaffoldPreviewView {
    static var preview: ScaffoldPreviewView {
      ScaffoldPreviewView(
        key: "G",
        specs: [
          ScaffoldSpecView(
            kind: .melody, title: "Learn the melody",
            rationale: "Hear the tune before you build on it",
            key: "G", fallback: false, alreadyLinked: true),
          ScaffoldSpecView(
            kind: .shells, title: "Shells",
            rationale: "3rd + 7th of every chord · the voice-leading skeleton",
            key: "G", fallback: false, alreadyLinked: false),
          ScaffoldSpecView(
            kind: .guideToneLines, title: "Guide-tone lines",
            rationale: "Connect 3rds to 7ths across each change",
            key: "G", fallback: false, alreadyLinked: false),
          ScaffoldSpecView(
            kind: .scalesToChordTones, title: "Scales to chord tones",
            rationale: "Run each chord-scale, landing on a chord tone",
            key: "G", fallback: true, alreadyLinked: false),
          ScaffoldSpecView(
            kind: .constrainedImprov, title: "Constrained improv",
            rationale: "Chord tones only, then rhythm · one ladder",
            key: "G", fallback: false, alreadyLinked: false),
        ],
        fallbackTotal: 1)
    }
  }
#endif
