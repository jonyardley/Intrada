import SwiftUI

/// Tag editor for the add/edit forms: removable chips plus a field that suggests
/// existing tags inline (the same reveal as `AutocompleteField`). Case-insensitive
/// duplicates are ignored. The shell supplies the pool; no domain logic here.
struct TagChipInput: View {
  let label: String
  @Binding var tags: [String]
  var suggestions: [String]
  /// True while tags are what a refused save named (#1595).
  var faulted: Bool = false

  @State private var draft = ""
  @FocusState private var focused: Bool

  /// Previews/snapshots can't drive `@FocusState`; forces the list open.
  var initiallyShowingSuggestions: Bool = false

  private var matches: [String] {
    let query = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    let unused = suggestions.filter { suggestion in
      !tags.contains { $0.localizedCaseInsensitiveCompare(suggestion) == .orderedSame }
    }
    let pool =
      query.isEmpty
      ? unused
      : unused.filter {
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
      VStack(alignment: .leading, spacing: IntradaSpacing.controlGap) {
        Text(label)
          .font(IntradaFont.metaMedium)
          .foregroundStyle(faulted ? IntradaColor.danger : IntradaColor.inkSecondary)
        if !tags.isEmpty {
          FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
              TagChip(tag, onRemove: { remove(tag) })
            }
          }
        }
        TextField("Add a tag", text: $draft)
          .font(IntradaFont.field)
          .foregroundStyle(IntradaColor.ink)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .focused($focused)
          .submitLabel(.done)
          .onSubmit { add(draft) }
          .accessibilityHint(FaultMark.spoken(faulted))
      }
      .padding(.vertical, 10)
      .padding(.horizontal, IntradaSpacing.card)
      .frame(maxWidth: .infinity, alignment: .leading)
      .faultWash(faulted, over: IntradaColor.cardFill)
      .zIndex(1)

      if showSuggestions {
        suggestionList
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .clipped()
    .animation(.snappy(duration: 0.22), value: showSuggestions)
  }

  private func add(_ raw: String) {
    let tag = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !tag.isEmpty,
      !tags.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame })
    else {
      draft = ""
      return
    }
    tags.append(tag)
    draft = ""
  }

  private func remove(_ tag: String) {
    tags.removeAll { $0 == tag }
  }

  private var suggestionList: some View {
    InlineSuggestionList(
      matches: matches,
      systemImage: "plus",
      accessibilityHint: { "Adds the tag \($0)" },
      onPick: { add($0) })
  }
}

#if DEBUG
  #Preview {
    struct Demo: View {
      @State private var tags = ["classical", "recital"]
      let pool = ["classical", "recital", "jazz", "warm-up", "technique", "etude"]
      var body: some View {
        ZStack {
          PaperBackground()
          ScrollView {
            VStack(spacing: IntradaSpacing.card) {
              VStack(spacing: 0) {
                TagChipInput(
                  label: "Tags", tags: $tags, suggestions: pool,
                  initiallyShowingSuggestions: true)
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
