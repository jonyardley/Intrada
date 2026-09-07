import SharedTypes
import SwiftUI

/// Create sheet for a new library item. Sends `Event.item(.add)`, or
/// `.addPieceInFull` once the form is carrying a chart or a staged exercise:
/// the core validates and (in local-first mode) persists locally with a
/// client-minted ulid; the shell only collects field values.
struct LibraryAddScreen: View {
  @Environment(Store.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var form: ItemFormModel
  @State private var expandsExercises = false
  @State private var editingChart = false
  @State private var writingExercise = false
  @State private var choosingExercises = false
  /// Set when the exercise is being written for a piece: the core creates and
  /// links it in one event, so it can never land unlinked (#1431).
  private let relatedToPieceId: String?

  init(defaultKind: ItemKind = .piece) {
    _form = State(initialValue: ItemFormModel(kind: defaultKind))
    relatedToPieceId = nil
  }

  init(relatedToPieceId: String) {
    _form = State(initialValue: ItemFormModel(kind: .exercise))
    self.relatedToPieceId = relatedToPieceId
  }

  #if DEBUG
    init(previewError: String) {
      let form = ItemFormModel(kind: .piece)
      form.formError = previewError
      _form = State(initialValue: form)
      relatedToPieceId = nil
    }

    /// Renders a form already carrying staged material. The sections live here
    /// rather than in `ItemFormScaffold`, so a snapshot of the scaffold alone
    /// cannot reach them.
    init(previewForm: ItemFormModel) {
      _form = State(initialValue: previewForm)
      relatedToPieceId = nil
    }
  #endif

  var body: some View {
    ItemFormScaffold(
      form: form,
      title: "New \(form.kind.label)",
      confirmLabel: "Add",
      composerSuggestions: store.viewModel?.availableComposers ?? [],
      tagSuggestions: store.viewModel?.availableTags ?? [],
      showsKindPicker: relatedToPieceId == nil,
      header: {
        ScanPageEntry(
          photoId: recognition?.photoId,
          status: recognition?.status ?? .idle,
          readNothing: recognition?.draft.map(readNothing) ?? false,
          onCaptured: { store.send(.item(.readPhoto(photoId: $0))) })
      },
      sections: {
        // Only a piece carries a chart and related exercises, and only on the
        // create path: the edit path keeps its existing shape (T21).
        if showsSections {
          chartSection
          exercisesSection
        }
      }
    ) {
      send()
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
    .sheet(isPresented: $writingExercise) {
      DraftExerciseSheet(onDone: { form.stagedExercises.append($0) })
    }
    .sheet(isPresented: $choosingExercises) {
      LinkedItemPickerSheet(
        kind: .exercise,
        available: store.viewModel?.allItems.filter { $0.itemType == .exercise } ?? [],
        linkedIds: form.stagedExercises.compactMap(\.existingId),
        onApply: applyChosen)
    }
  }

  private var showsSections: Bool {
    relatedToPieceId == nil && form.kind == .piece
  }

  // ── Chord chart ──

  @ViewBuilder private var chartSection: some View {
    if form.chartText.isEmpty {
      FormSectionRow(title: "Chord chart", accessory: .opensSheet) { editingChart = true }
        .cardSurface()
    } else {
      StagedChartCard(
        text: form.chartText, readWeakly: form.readFrom[.chart],
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
          ForEach(form.stagedExercises) { staged in
            HairlineDivider()
            DraftItemRow(
              title: staged.title, meta: staged.meta,
              onRemove: { form.stagedExercises.removeAll { $0.id == staged.id } })
          }
        }
        HairlineDivider()
        exercisesActions
      }
    }
    .cardSurface()
  }

  /// Two plain accent actions, never a `BrandBarButton`: Add is the screen's
  /// only primary and a filled bar here would out-shout it.
  ///
  /// Stacked while the list is empty, where the actions are the whole content
  /// and "Choose one" has no rows above it to give "one" an antecedent. Also
  /// stacked at accessibility sizes, where side by side breaks "Create an
  /// exercise" onto three lines in half a phone's width.
  @ViewBuilder private var exercisesActions: some View {
    if stacksActions {
      VStack(spacing: 0) {
        actionButton(
          "Create an exercise", icon: "plus",
          spoken: "Create an exercise for this piece"
        ) { writingExercise = true }
        HairlineDivider()
        actionButton(
          "Choose one from the library",
          spoken: "Choose an existing exercise for this piece"
        ) { choosingExercises = true }
      }
    } else {
      HStack(spacing: 0) {
        actionButton("Create an exercise", spoken: "Create an exercise for this piece") {
          writingExercise = true
        }
        actionButton("Choose one", spoken: "Choose an existing exercise for this piece") {
          choosingExercises = true
        }
      }
      .padding(IntradaSpacing.controlGap)
    }
  }

  private var stacksActions: Bool {
    form.stagedExercises.isEmpty || typeSize.isAccessibilitySize
  }

  private func actionButton(
    _ title: String, icon: String? = nil, spoken: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if let icon {
          Image(systemName: icon)
        }
        Text(title)
      }
      .font(IntradaFont.bodyMedium)
      .foregroundStyle(IntradaColor.accent)
      .frame(maxWidth: .infinity)
      .padding(.vertical, IntradaSpacing.cardCompact)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(spoken)
  }

  // `Swift.Set`, because `SharedTypes` exports a domain `Set` that shadows the
  // standard library type in this file (#1348).
  private func applyChosen(_ ids: Swift.Set<String>) {
    // Written exercises keep their place; chosen ones follow in library order,
    // because the picker hands back a set rather than a tap order.
    let drafts = form.stagedExercises.filter { $0.existingId == nil }
    form.stagedExercises =
      drafts
      + (store.viewModel?.allItems ?? [])
      .filter { ids.contains($0.id) }
      .map { .existing(id: $0.id, title: $0.title, meta: $0.subtitle) }
  }

  private func send() {
    if let pieceId = relatedToPieceId {
      store.send(.item(.addLinkedExercise(pieceId: pieceId, input: form.createInput())))
    } else if showsSections && form.hasStagedExtras {
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
