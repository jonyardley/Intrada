import SwiftUI

/// Shared bottom-sheet chrome. The inline title renders in Hanken Grotesk via RootView's
/// global nav-bar appearance; Done runs `onDone` then dismisses.
struct BottomSheet<Content: View, LeadingAction: View>: View {
  private let title: String
  private let detents: Set<PresentationDetent>
  private let confirmationLabel: String
  private let confirmationDisabled: Bool
  private let onDone: () -> Void
  private let leadingAction: LeadingAction
  private let content: Content

  @Environment(\.dismiss) private var dismiss

  init(
    title: String,
    detents: Set<PresentationDetent> = [.medium, .large],
    confirmationLabel: String = "Done",
    confirmationDisabled: Bool = false,
    onDone: @escaping () -> Void = {},
    @ViewBuilder leadingAction: () -> LeadingAction,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.detents = detents
    self.confirmationLabel = confirmationLabel
    self.confirmationDisabled = confirmationDisabled
    self.onDone = onDone
    self.leadingAction = leadingAction()
    self.content = content()
  }

  var body: some View {
    NavigationStack {
      ZStack {
        PaperBackground()
        content
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { leadingAction }
        ToolbarItem(placement: .confirmationAction) {
          Button(confirmationLabel) {
            onDone()
            dismiss()
          }
          .disabled(confirmationDisabled)
        }
      }
    }
    .presentationDetents(detents)
  }
}

extension BottomSheet where LeadingAction == EmptyView {
  init(
    title: String,
    detents: Set<PresentationDetent> = [.medium, .large],
    confirmationLabel: String = "Done",
    confirmationDisabled: Bool = false,
    onDone: @escaping () -> Void = {},
    @ViewBuilder content: () -> Content
  ) {
    self.init(
      title: title, detents: detents, confirmationLabel: confirmationLabel,
      confirmationDisabled: confirmationDisabled, onDone: onDone,
      leadingAction: { EmptyView() }, content: content)
  }
}
