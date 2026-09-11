import SwiftUI

/// Says a form field was filled from a photographed page rather than typed
/// (#1436). A weak read dims the glyph only, to `inkFaintIcon`; the label
/// stays at `inkSecondary` (#1458 — `inkFaint` fails AA on text).
struct FieldMark: View {
  let weak: Bool

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: "doc.viewfinder")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(weak ? IntradaColor.inkFaintIcon : IntradaColor.inkSecondary)
      Text("From the photo")
        .font(IntradaFont.micro)
        .fontWeight(.medium)
        .foregroundStyle(IntradaColor.inkSecondary)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.spoken(weak))
  }

  /// Also the field's own hint: the mark is a sibling element, so alone it is
  /// only reached by linear swipe, never by the text-fields rotor.
  static func spoken(_ weak: Bool?) -> String {
    switch weak {
    case .none: ""
    case .some(true): "Read from the photo, but not clearly. Worth checking"
    case .some(false): "Read from the photo"
    }
  }
}

#if DEBUG
  #Preview {
    VStack(alignment: .leading, spacing: IntradaSpacing.cardCompact) {
      FieldMark(weak: false)
      FieldMark(weak: true)
    }
    .padding()
    .background(IntradaColor.cardFill)
  }
#endif
