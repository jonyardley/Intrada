import SharedTypes
import SwiftUI

struct DraftExerciseSheet: View {
  @Environment(\.dismiss) private var dismiss

  @State private var title = ""
  @State private var key = ""
  @State private var modality: Modality?
  @State private var bpm = ""

  let onDone: (StagedExercise) -> Void

  var body: some View {
    NavigationStack {
      ZStack {
        PaperBackground()
        ScrollView {
          VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
            VStack(spacing: 0) {
              FormField(label: "Title", text: $title, placeholder: "Required")
              HairlineDivider()
              KeyPicker(label: "Key", key: $key, modality: $modality)
              HairlineDivider()
              FormField(label: "Beats per minute", text: $bpm, keyboard: .numberPad)
            }
            .cardSurface()

            Text("It joins the list here.")
              .font(IntradaFont.meta)
              .foregroundStyle(IntradaColor.inkSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(IntradaSpacing.card)
        }
      }
      .navigationTitle("New exercise")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", action: done)
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  private func done() {
    onDone(
      .draft(
        id: UUID(), title: title, key: key.trimmingCharacters(in: .whitespaces),
        modality: modality, bpm: bpm.trimmingCharacters(in: .whitespaces)))
    dismiss()
  }
}

#if DEBUG
  #Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
      DraftExerciseSheet(onDone: { _ in })
    }
  }
#endif
