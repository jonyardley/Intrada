import SwiftUI

struct FormSectionRow: View {
  enum Accessory {
    case opensSheet
    case collapsed
    case expanded
    case edit
  }

  let title: String
  let accessory: Accessory
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .firstTextBaseline, spacing: IntradaSpacing.cardCompact) {
        Text(title)
          .font(IntradaFont.cardTitle())
          .foregroundStyle(IntradaColor.ink)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
        trailing
      }
      .padding(IntradaSpacing.card)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityHint(hint)
    .accessibilityAddTraits(.isButton)
  }

  @ViewBuilder private var trailing: some View {
    switch accessory {
    case .edit:
      Text("Edit")
        .font(IntradaFont.bodyMedium)
        .foregroundStyle(IntradaColor.accent)
    case .opensSheet, .collapsed, .expanded:
      Image(systemName: chevron)
        .font(IntradaFont.bodyMedium)
        .foregroundStyle(IntradaColor.inkFaint)
    }
  }

  private var chevron: String {
    switch accessory {
    case .opensSheet: "chevron.right"
    case .collapsed: "chevron.down"
    case .expanded: "chevron.up"
    case .edit: "chevron.right"
    }
  }

  private var hint: String {
    switch accessory {
    case .opensSheet, .edit: "Opens the editor"
    case .collapsed: "Expands the section"
    case .expanded: "Collapses the section"
    }
  }
}

#if DEBUG
  #Preview {
    VStack(spacing: IntradaSpacing.card) {
      FormSectionRow(title: "Chord chart", accessory: .opensSheet, action: {})
        .cardSurface()
      FormSectionRow(title: "Related exercises", accessory: .collapsed, action: {})
        .cardSurface()
      FormSectionRow(title: "Related exercises", accessory: .expanded, action: {})
        .cardSurface()
      FormSectionRow(title: "Chord chart", accessory: .edit, action: {})
        .cardSurface()
    }
    .padding(IntradaSpacing.card)
    .background(LinearGradient.paper)
  }
#endif
