import SharedTypes
import SwiftUI

/// Create sheet for a new library item. Sends `Event.item(.add)`, the core
/// validates and (in local-first mode) persists locally with a client-minted
/// ulid; the shell only collects field values.
struct LibraryAddScreen: View {
  @Environment(Store.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var form: ItemFormModel
  @State private var expandsExercises = false
  @State private var editingChart = false
  @State private var choosingExercises = false

  init(defaultKind: ItemKind = .piece) {
    _form = State(initialValue: ItemFormModel(kind: defaultKind))
  }

  #if DEBUG
    init(previewError: String) {
      let form = ItemFormModel(kind: .piece)
      form.formError = previewError
      _form = State(initialValue: form)
    }

    init(previewForm: ItemFormModel) {
      _form = State(initialValue: previewForm)
    }
  #endif

  var body: some View {
    ItemFormScaffold(
      form: form,
      title: "New \(form.kind.label)",
      confirmLabel: "Add",
      composerSuggestions: store.viewModel?.availableComposers ?? [],
      tagSuggestions: store.viewModel?.availableTags ?? [],
      header: {
        ScanPageEntry(
          photoId: recognition?.photoId,
          status: recognition?.status ?? .idle,
          readNothing: recognition?.draft.map(readNothing) ?? false,
          onCaptured: { store.send(.item(.readPhoto(photoId: $0))) })
      },
      sections: {
        if showsSections {
          chartSection
            .id(FormAnchor.chart)
          exercisesSection
        }
      }
    ) {
      send()
    }
    // Switching kind drops what was staged: an exercise carries neither a
    // chart nor related exercises, so the sections vanishing is the only sign.
    .onChange(of: form.kind) { _, kind in
      guard kind != .piece else { return }
      form.chartText = ""
      form.stagedExercises = []
      expandsExercises = false
    }
    // Keyed on the projection, not the draft: re-picking the same library file
    // reads to an equal `PhotoDraft`, so a rescan would silently do nothing.
    .onChange(of: recognition) { _, next in
      form.photoId = next?.photoId
      guard let draft = next?.draft else { return }
      form.fill(from: draft)
    }
    .sheet(isPresented: $editingChart) {
      ChordChartEditSheet(
        text: form.chartText, pieceKey: form.key.isEmpty ? nil : form.key,
        pieceModality: form.modality,
        onSave: { form.chartText = $0 })
    }
    .sheet(isPresented: $choosingExercises) {
      LinkedItemPickerSheet(
        kind: .exercise,
        available: store.viewModel?.allItems.filter { $0.itemType == .exercise } ?? [],
        linkedIds: form.stagedExercises.compactMap(\.existingId),
        existingDrafts: form.stagedExercises.filter { $0.existingId == nil },
        onApply: applyChosen)
    }
  }

  private var showsSections: Bool {
    form.kind == .piece
  }

  // ── Chord chart ──

  @ViewBuilder private var chartSection: some View {
    if form.chartText.isEmpty {
      FormSectionRow(title: "Chord chart", accessory: .opensSheet) { editingChart = true }
        .cardSurface()
    } else {
      StagedChartCard(
        text: form.chartText, readWeakly: form.readFrom[.chart], faulted: form.faultsChart,
        faultedBarNumber: form.faultedBarNumber,
        onEdit: { editingChart = true }
      )
      .cardSurface()
    }
  }

  // ── Related exercises ──

  @ViewBuilder private var exercisesSection: some View {
    VStack(spacing: 0) {
      FormSectionRow(
        title: "Related exercises",
        accessory: expandsExercises || !form.stagedExercises.isEmpty ? .expanded : .collapsed
      ) {
        withAnimation(reduceMotion ? nil : IntradaMotion.standard) {
          expandsExercises.toggle()
        }
      }
      if expandsExercises || !form.stagedExercises.isEmpty {
        if form.stagedExercises.isEmpty {
          Text("Scales, arpeggios, and anything else you practise alongside this piece.")
            .font(IntradaFont.body)
            .foregroundStyle(IntradaColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, IntradaSpacing.card)
            .padding(.bottom, IntradaSpacing.cardCompact)
        } else {
          ForEach(Array(form.stagedExercises.enumerated()), id: \.element.id) { index, staged in
            // The anchor rides the divider: an explicit id on the row itself
            // would override the identity `ForEach` diffs the list by.
            HairlineDivider()
              .id(FormAnchor.row(index))
            DraftItemRow(
              title: staged.title, meta: staged.meta, faulted: form.faults(row: index),
              faultedField: form.faultedField(row: index),
              onRemove: { form.stagedExercises.removeAll { $0.id == staged.id } })
          }
        }
        HairlineDivider()
        exercisesActions
      }
    }
    .cardSurface()
  }

  private var exercisesActions: some View {
    Button {
      choosingExercises = true
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "plus")
        Text("Add exercise")
      }
      .font(IntradaFont.bodyMedium)
      .foregroundStyle(IntradaColor.accent)
      .frame(maxWidth: .infinity)
      .padding(.vertical, IntradaSpacing.cardCompact)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Add an exercise for this piece")
  }

  // `Swift.Set`, because `SharedTypes` exports a domain `Set` that shadows the
  // standard library type in this file (#1348).
  private func applyChosen(_ ids: Swift.Set<String>, _ drafts: [StagedExercise]) {
    form.stagedExercises =
      drafts
      + (store.viewModel?.allItems ?? [])
      .filter { ids.contains($0.id) }
      .map { .existing(id: $0.id, title: $0.title, meta: $0.subtitle) }
  }

  private func send() {
    if showsSections && form.hasStagedExtras {
      store.send(
        .item(
          .addPieceInFull(
            piece: form.createInput(),
            chart: form.chartText.isEmpty ? nil : form.chartText,
            exercises: form.scaffoldEntries())))
    } else {
      store.send(.item(.add(form.createInput())))
    }
  }

  private var recognition: PhotoRecognitionView? { store.viewModel?.photoRecognition }

  private func readNothing(_ draft: PhotoDraft) -> Bool {
    draft.title == nil && draft.composer == nil && draft.tempo == nil && draft.chartText == nil
  }
}

#if DEBUG
  #Preview {
    LibraryAddScreen()
      .environment(Store.preview)
  }
#endif
