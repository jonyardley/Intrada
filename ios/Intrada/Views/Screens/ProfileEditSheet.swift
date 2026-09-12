import SharedTypes
import SwiftUI

/// The profile's edit sheet: name, instrument with suggestions, the icon with
/// a way to pick another, and the eight swatches. Save sends one event; the
/// core validates, and the sheet dismisses only when it accepts (#1692).
struct ProfileEditSheet: View {
  @Environment(Store.self) private var store
  @Environment(\.dismiss) private var dismiss

  @State private var name = ""
  @State private var instrument = ""
  @State private var iconChoice: InstrumentIcon?
  @State private var colour: HighlighterColour = .butter
  @State private var formError: String?
  @State private var faultedField: ProfileField?
  @State private var choosingIcon = false

  init() {}

  #if DEBUG
    init(previewError: String, field: ProfileField) {
      _formError = State(initialValue: previewError)
      _faultedField = State(initialValue: field)
    }
  #endif

  private var profile: ProfileView? { store.viewModel?.profile }

  var body: some View {
    NavigationStack {
      ZStack {
        PaperBackground()
        VStack(spacing: 0) {
          if let formError {
            FormErrorBanner(message: formError)
              .padding(.horizontal, IntradaSpacing.card)
              .padding(.top, IntradaSpacing.cardCompact)
              .transition(.move(edge: .top).combined(with: .opacity))
          }
          ScrollView {
            VStack(alignment: .leading, spacing: IntradaSpacing.card) {
              iconCard
              fields
              swatches
            }
            .padding(IntradaSpacing.card)
          }
        }
      }
      .navigationTitle("Profile")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save)
        }
      }
      .sheet(isPresented: $choosingIcon) {
        InstrumentIconPicker(
          suggested: profile?.suggestedIcon ?? .other, choice: $iconChoice)
      }
    }
    // The sheet wears the swatch under the finger; the rest of the app
    // follows once the core has accepted the save.
    .environment(\.marker, IntradaColor.marker(colour))
    .onAppear(perform: load)
  }

  private func load() {
    guard let profile else { return }
    name = profile.name
    instrument = profile.instrument
    iconChoice = profile.icon == profile.suggestedIcon ? nil : profile.icon
    colour = profile.colour
  }

  private var shownIcon: InstrumentIcon {
    iconChoice ?? profile?.suggestedIcon ?? .other
  }

  private var iconCaption: String {
    if iconChoice != nil { return "Chosen by you" }
    if let suggested = profile?.suggestedIcon, suggested != .other {
      return "Matches \(suggested.tileLabel.lowercased())"
    }
    return "No match"
  }

  private var iconCard: some View {
    HStack(spacing: IntradaSpacing.row) {
      ProfileBadge(icon: shownIcon)
      VStack(alignment: .leading, spacing: 3) {
        Text("Icon")
          .font(IntradaFont.metaMedium)
          .foregroundStyle(IntradaColor.inkSecondary)
        Text(iconCaption)
          .font(IntradaFont.meta)
          .foregroundStyle(IntradaColor.inkSecondary)
      }
      Spacer(minLength: IntradaSpacing.controlGap)
      Button("Change") { choosingIcon = true }
        .font(IntradaFont.button)
        .foregroundStyle(IntradaColor.ink)
        .padding(.horizontal, IntradaSpacing.cardCompact)
        .frame(height: 36)
        .background(IntradaColor.cardFill)
        .overlay(
          RoundedRectangle(cornerRadius: IntradaRadius.control)
            .stroke(IntradaColor.divider, lineWidth: 1)
        )
        .accessibilityLabel("Change icon")
    }
    .padding(.vertical, IntradaSpacing.cardCompact)
    .padding(.horizontal, IntradaSpacing.card)
    .cardSurface()
  }

  private var fields: some View {
    VStack(spacing: 0) {
      FormField(
        label: "Name", text: $name, placeholder: "Your name",
        autocapitalization: .words, faulted: faultedField == .name)
      HairlineDivider()
      AutocompleteField(
        label: "Instrument", text: $instrument, placeholder: "e.g. Cello",
        suggestions: InstrumentNames.suggestions, faulted: faultedField == .instrument)
    }
    .cardSurface()
  }

  private var swatches: some View {
    VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      Eyebrow("Highlighter")
      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 4),
        spacing: IntradaSpacing.cardCompact
      ) {
        ForEach(HighlighterColour.all, id: \.self) { swatch in
          Button {
            colour = swatch
            UISelectionFeedbackGenerator().selectionChanged()
          } label: {
            VStack(spacing: 6) {
              Circle()
                .fill(IntradaColor.marker(swatch))
                .frame(width: 40, height: 40)
                .overlay {
                  if swatch == colour {
                    Image(systemName: "checkmark")
                      .font(.system(size: 15, weight: .bold))
                      .foregroundStyle(IntradaColor.onMarker)
                  }
                }
              Text(swatch.label)
                .font(IntradaFont.metaMedium)
                .foregroundStyle(swatch == colour ? IntradaColor.ink : IntradaColor.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(swatch.label)
          .accessibilityAddTraits(swatch == colour ? .isSelected : [])
        }
      }
      .padding(.vertical, IntradaSpacing.cardCompact)
      .padding(.horizontal, IntradaSpacing.controlGap)
      .cardSurface()
    }
  }

  // Never dismiss or celebrate until the core has accepted (#1595).
  private func save() {
    formError = nil
    faultedField = nil
    store.send(
      .profile(
        .save(Profile(name: name, instrument: instrument, iconChoice: iconChoice, colour: colour))))
    if let error = store.viewModel?.error {
      if case .profile(let field) = store.viewModel?.errorTarget {
        faultedField = field
      }
      withAnimation { formError = error }
      store.send(.clearError)
      UINotificationFeedbackGenerator().notificationOccurred(.error)
      UIAccessibility.post(notification: .announcement, argument: "Error: \(error)")
    } else {
      UINotificationFeedbackGenerator().notificationOccurred(.success)
      dismiss()
    }
  }
}

/// The instrument field's suggestion pool: vocabulary for the autocomplete,
/// not a domain decision; the core decides what each one matches.
enum InstrumentNames {
  static let suggestions: [String] = [
    "Accordion", "Alto saxophone", "Bagpipes", "Banjo", "Baritone", "Bass guitar", "Bassoon",
    "Cello", "Clarinet", "Cor anglais", "Cornet", "Double bass", "Drums", "Electric guitar",
    "Euphonium", "Flute", "French horn", "Guitar", "Harp", "Harpsichord", "Mandolin", "Marimba",
    "Oboe", "Organ", "Percussion", "Piano", "Piccolo", "Recorder", "Saxophone", "Soprano",
    "Tenor saxophone", "Timpani", "Trombone", "Trumpet", "Tuba", "Ukulele", "Viola", "Violin",
    "Voice",
  ]
}

#if DEBUG
  #Preview {
    ProfileEditSheet()
      .environment(Store.previewProfile)
  }
#endif
