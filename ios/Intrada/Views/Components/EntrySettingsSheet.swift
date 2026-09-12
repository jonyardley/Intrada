import SharedTypes
import SwiftUI

/// Per-entry session-builder settings: an "Aim" note, a rep-target counter, and
/// a planned duration — opened by tapping a builder row. Every field pushes on
/// change (no separate Save), matching the `SessionSummaryScreen` notes idiom.
struct EntrySettingsSheet: View {
  let entry: SetlistEntryView
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss

  @State private var intention: String
  @State private var tracksReps: Bool
  @State private var repTarget: Int
  @State private var hasPlannedDuration: Bool
  @State private var plannedMinutes: Int
  @State private var variantId: String?

  // Looked up rather than threaded in, since the sheet only ever holds the
  // flat entry — mirrors the same lookup in FocusPlayerScreen.
  private var variants: [VariantView] {
    store.viewModel?.items.first(where: { $0.id == entry.itemId })?.variants ?? []
  }

  // Mirrors crates/intrada-core/src/validation.rs MIN/MAX_REP_TARGET and
  // DEFAULT_REP_TARGET.
  private let repTargetRange = 3...10
  private let defaultRepTarget = 10
  // Mirrors MIN/MAX_PLANNED_DURATION_SECS (60–3600s), in whole minutes.
  private let durationRange = 1...60

  init(entry: SetlistEntryView) {
    self.entry = entry
    _intention = State(initialValue: entry.intention ?? "")
    _tracksReps = State(initialValue: entry.plannedRepTarget != nil)
    _repTarget = State(initialValue: Int(entry.plannedRepTarget ?? UInt8(defaultRepTarget)))
    _hasPlannedDuration = State(initialValue: entry.plannedDurationSecs != nil)
    _plannedMinutes = State(initialValue: Int((entry.plannedDurationSecs ?? 360) / 60))
    _variantId = State(initialValue: entry.plannedVariationId)
  }

  var body: some View {
    BottomSheet(title: entry.itemTitle, detents: [.medium]) {
      ScrollView {
        VStack(alignment: .leading, spacing: IntradaSpacing.section) {
          aimSection
          if !variants.isEmpty {
            stepSection
          }
          repsSection
          durationSection
          // A grouped piece is the block's anchor: removing it dissolves the
          // whole block (core §7.4), so that call stays with the header menu's
          // explicit "Just the piece" / "Remove block" wording.
          if !(entry.itemType == .piece && entry.groupId != nil) {
            removeButton
          }
        }
        .padding(IntradaSpacing.card)
      }
    }
  }

  private var aimSection: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      Eyebrow("Aim")
      TextField("What are you aiming for on this one?", text: $intention, axis: .vertical)
        .lineLimit(2...4)
        .font(IntradaFont.field)
        .foregroundStyle(IntradaColor.ink)
        .padding(IntradaSpacing.cardCompact)
        .cardSurface(cornerRadius: IntradaRadius.control)
        .onChange(of: intention) { _, value in
          let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
          let next = trimmed.isEmpty ? nil : trimmed
          guard next != entry.intention else { return }
          store.send(.session(.setEntryIntention(entryId: entry.id, intention: next)))
        }
    }
  }

  private var stepSection: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      Eyebrow("Step")
      Menu {
        ForEach(variants, id: \.id) { step in
          Button(step.label) {
            guard step.id != variantId else { return }
            variantId = step.id
            store.send(.session(.setEntryVariant(entryId: entry.id, variantId: step.id)))
          }
        }
      } label: {
        HStack {
          Text(selectedStepLabel)
            .font(IntradaFont.body)
            .foregroundStyle(IntradaColor.ink)
          Spacer()
          Image(systemName: "chevron.up.chevron.down")
            .imageScale(.small)
            .foregroundStyle(IntradaColor.inkFaint)
        }
        .padding(IntradaSpacing.cardCompact)
        .cardSurface(cornerRadius: IntradaRadius.control)
      }
      .accessibilityLabel("Step: \(selectedStepLabel)")
      .accessibilityHint("Choose a different step")
      .buttonStyle(.plain)
    }
  }

  private var selectedStepLabel: String {
    variants.first(where: { $0.id == variantId })?.label ?? "Not tagged to a step"
  }

  private var repsSection: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      Toggle(isOn: $tracksReps) { Eyebrow("Track reps") }
        .tint(IntradaColor.accent)
        .onChange(of: tracksReps) { _, on in
          store.send(
            .session(.setRepTarget(entryId: entry.id, target: on ? UInt8(repTarget) : nil)))
        }
      if tracksReps {
        Stepper(value: $repTarget, in: repTargetRange) {
          Text("Target: \(repTarget) reps")
            .font(IntradaFont.body).foregroundStyle(IntradaColor.ink)
        }
        .onChange(of: repTarget) { _, value in
          guard tracksReps else { return }
          store.send(.session(.setRepTarget(entryId: entry.id, target: UInt8(value))))
        }
      }
    }
    .padding(IntradaSpacing.cardCompact)
    .cardSurface(cornerRadius: IntradaRadius.control)
  }

  private var durationSection: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
      Toggle(isOn: $hasPlannedDuration) { Eyebrow("Planned duration") }
        .tint(IntradaColor.accent)
        .onChange(of: hasPlannedDuration) { _, on in
          store.send(
            .session(
              .setEntryDuration(
                entryId: entry.id, durationSecs: on ? UInt32(plannedMinutes * 60) : nil)))
        }
      if hasPlannedDuration {
        Stepper(value: $plannedMinutes, in: durationRange) {
          Text("\(plannedMinutes) min").font(IntradaFont.body).foregroundStyle(IntradaColor.ink)
        }
        .onChange(of: plannedMinutes) { _, value in
          guard hasPlannedDuration else { return }
          store.send(
            .session(.setEntryDuration(entryId: entry.id, durationSecs: UInt32(value * 60))))
        }
      }
    }
    .padding(IntradaSpacing.cardCompact)
    .cardSurface(cornerRadius: IntradaRadius.control)
  }

  // The row's non-gesture removal path (T4): dropping it from today's session
  // leaves the piece↔exercise relation untouched.
  private var removeButton: some View {
    Button(role: .destructive) {
      if store.send(.session(.removeFromSetlist(entryId: entry.id)), onSuccess: .impact) {
        dismiss()
      }
    } label: {
      Text("Remove from this session")
        .font(IntradaFont.bodyMedium)
        .frame(maxWidth: .infinity)
        .padding(.vertical, IntradaSpacing.cardCompact)
    }
    .buttonStyle(.plain)
    .foregroundStyle(IntradaColor.danger)
    .cardSurface(cornerRadius: IntradaRadius.control)
  }
}

#if DEBUG
  #Preview("Entry settings") {
    Color.black.opacity(0.2).ignoresSafeArea()
      .sheet(isPresented: .constant(true)) {
        EntrySettingsSheet(entry: .previewGroupedScales).environment(Store.previewBuildingGrouped)
      }
  }
#endif
