import SharedTypes
import SwiftUI

/// Shared body for the add/edit item sheets: the field cards plus the
/// confirm/cancel toolbar and the error-reconcile flow. `send` dispatches the
/// add/update event; the scaffold owns the "don't celebrate until the core
/// confirms" handling so both screens behave identically.
struct ItemFormScaffold<Header: View, Sections: View>: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss

  @Bindable var form: ItemFormModel
  let title: String
  let confirmLabel: String
  let composerSuggestions: [String]
  let tagSuggestions: [String]
  // Hidden when the caller already fixes the kind (creating an exercise from a
  // piece), so the form can't offer a choice the core will discard anyway.
  var showsKindPicker = true
  /// Sits above the fields. The add screen puts the scan entry here rather than
  /// as a row inside the form: once a page is read it is not a field beside
  /// title and composer, it is what fills them (#1446).
  @ViewBuilder var header: () -> Header
  /// Appended below Tags, so the existing field order is untouched and the edit
  /// path is unchanged. The create form puts the chart and the related
  /// exercises here (T21).
  @ViewBuilder var sections: () -> Sections
  let send: () -> Void

  init(
    form: ItemFormModel, title: String, confirmLabel: String, composerSuggestions: [String],
    tagSuggestions: [String], showsKindPicker: Bool = true,
    @ViewBuilder header: @escaping () -> Header = { EmptyView() },
    @ViewBuilder sections: @escaping () -> Sections = { EmptyView() },
    send: @escaping () -> Void
  ) {
    self.form = form
    self.title = title
    self.confirmLabel = confirmLabel
    self.composerSuggestions = composerSuggestions
    self.tagSuggestions = tagSuggestions
    self.showsKindPicker = showsKindPicker
    self.header = header
    self.sections = sections
    self.send = send
  }

  var body: some View {
    NavigationStack {
      ZStack {
        PaperBackground()
        VStack(spacing: 0) {
          if let formError = form.formError {
            FormErrorBanner(message: formError)
              .padding(.horizontal, IntradaSpacing.card)
              .padding(.top, IntradaSpacing.cardCompact)
              .transition(.move(edge: .top).combined(with: .opacity))
          }
          ScrollView {
            VStack(spacing: IntradaSpacing.card) {
              header()

              if showsKindPicker {
                KindSegment(selection: $form.kind)
              }

              VStack(spacing: 0) {
                FormField(
                  label: "Title", text: $form.title, placeholder: "Required",
                  readWeakly: form.readFrom[.title])
                HairlineDivider()
                AutocompleteField(
                  label: "Composer", text: $form.composer, suggestions: composerSuggestions,
                  readWeakly: form.readFrom[.composer])
                HairlineDivider()
                KeyPicker(label: "Key", key: $form.key, modality: $form.modality)
              }
              .cardSurface()

              VStack(spacing: 0) {
                FormField(
                  label: "Tempo marking", text: $form.marking, placeholder: "e.g. Allegro",
                  readWeakly: form.readFrom[.marking])
                HairlineDivider()
                FormField(
                  label: "Beats per minute", text: $form.bpm, keyboard: .numberPad,
                  readWeakly: form.readFrom[.bpm])
              }
              .cardSurface()

              FormField(label: "Notes", text: $form.notes, axis: .vertical)
                .cardSurface()

              VStack(spacing: 0) {
                TagChipInput(label: "Tags", tags: $form.tags, suggestions: tagSuggestions)
              }
              .cardSurface()

              sections()
            }
            .padding(IntradaSpacing.card)
          }
        }
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(confirmLabel, action: confirm)
            .disabled(!form.canSubmit)
        }
      }
    }
  }

  // Don't celebrate or dismiss until the core confirms: a validation reject or
  // failed local write surfaces in viewModel.error, which we keep on screen.
  private func confirm() {
    form.formError = nil
    send()
    if let error = store.viewModel?.error {
      withAnimation { form.formError = error }
      // Show it inline only; clear the core error so the global banner doesn't
      // also surface it behind/after this sheet (validation re-sets it directly).
      store.send(.clearError)
      UINotificationFeedbackGenerator().notificationOccurred(.error)
      UIAccessibility.post(notification: .announcement, argument: "Error: \(error)")
    } else {
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      dismiss()
    }
  }
}
