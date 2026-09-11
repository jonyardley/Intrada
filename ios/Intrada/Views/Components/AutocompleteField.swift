import SwiftUI

/// A `FormField` whose matching `suggestions` reveal inline below the input (the
/// same in-place reveal as `KeyPicker`, so the card grows rather than overlaying
/// its neighbours). The shell supplies the pool; this view owns no domain logic.
struct AutocompleteField: View {
  let label: String
  @Binding var text: String
  var placeholder: String = ""
  var suggestions: [String]
  var autocapitalization: TextInputAutocapitalization = .words
  var readWeakly: Bool?
  var faulted: Bool = false

  @FocusState private var focused: Bool

  /// Previews/snapshot tests can't drive `@FocusState`; this forces the open
  /// state so the revealed list is renderable. Runtime always leaves it false.
  var initiallyShowingSuggestions: Bool = false

  private var matches: [String] {
    let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let pool =
      query.isEmpty
      ? suggestions
      : suggestions.filter {
        $0.localizedCaseInsensitiveContains(query)
          && $0.localizedCaseInsensitiveCompare(query) != .orderedSame
      }
    return Array(pool.prefix(6))
  }

  private var showSuggestions: Bool {
    (focused || initiallyShowingSuggestions) && !matches.isEmpty
  }

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 4) {
        Text(label)
          .font(IntradaFont.metaMedium)
          .foregroundStyle(faulted ? IntradaColor.danger : IntradaColor.inkSecondary)
        TextField(placeholder, text: $text)
          .font(IntradaFont.field)
          .foregroundStyle(IntradaColor.ink)
          .textInputAutocapitalization(autocapitalization)
          .autocorrectionDisabled()
          .focused($focused)
          .accessibilityIdentifier(label)
          .accessibilityHint(hint)
        if let readWeakly {
          FieldMark(weak: readWeakly)
        }
      }
      .padding(.vertical, 10)
      .padding(.horizontal, IntradaSpacing.card)
      .frame(maxWidth: .infinity, alignment: .leading)
      // Opaque fill + zIndex so the list slides *behind* the input on
      // open/close rather than over it (the `KeyPicker` reveal trick).
      .faultWash(faulted, over: IntradaColor.cardFill)
      .zIndex(1)

      if showSuggestions {
        suggestionList
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .clipped()
    // Animate only the reveal — filtered rows update instantly as you type, so
    // keystrokes stay responsive instead of re-animating the whole list.
    .animation(.snappy(duration: 0.22), value: showSuggestions)
  }

  private var hint: String {
    [FaultMark.spoken(faulted), FieldMark.spoken(readWeakly)]
      .filter { !$0.isEmpty }
      .joined(separator: ". ")
  }

  private var suggestionList: some View {
    InlineSuggestionList(
      matches: matches,
      systemImage: "arrow.up.left",
      accessibilityHint: { "Fills \(label) with \($0)" },
      onPick: {
        text = $0
        focused = false
      })
  }
}

#if DEBUG
  #Preview {
    struct Demo: View {
      @State private var empty = ""
      @State private var typing = "Bach"
      let pool = ["Bach", "Beethoven", "Brahms", "Chopin", "Debussy", "Ravel"]
      var body: some View {
        ZStack {
          PaperBackground()
          ScrollView {
            VStack(spacing: IntradaSpacing.card) {
              VStack(spacing: 0) {
                AutocompleteField(
                  label: "Composer", text: $typing, suggestions: pool,
                  initiallyShowingSuggestions: true)
              }.cardSurface()
              VStack(spacing: 0) {
                AutocompleteField(label: "Composer", text: $empty, suggestions: pool)
              }.cardSurface()
            }
            .padding(IntradaSpacing.card)
          }
        }
      }
    }
    return Demo()
  }
#endif
