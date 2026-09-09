import SwiftUI

/// 16pt input minimum avoids iOS zoom-on-focus (CLAUDE.md iOS rules).
struct FormField: View {
  let label: String
  @Binding var text: String
  var placeholder: String = ""
  var axis: Axis = .horizontal
  var keyboard: UIKeyboardType = .default
  var autocapitalization: TextInputAutocapitalization = .sentences
  /// Non-nil while the value is what a photographed page was read into, `true`
  /// when that read was weak (#1436).
  var readWeakly: Bool?
  var faulted: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(IntradaFont.metaMedium)
        .foregroundStyle(faulted ? IntradaColor.danger : IntradaColor.inkSecondary)
      TextField(placeholder, text: $text, axis: axis)
        .font(IntradaFont.field)
        .foregroundStyle(IntradaColor.ink)
        .keyboardType(keyboard)
        .textInputAutocapitalization(autocapitalization)
        .accessibilityHint(hint)
      if let readWeakly {
        FieldMark(weak: readWeakly)
      }
    }
    .padding(.vertical, 10)
    .padding(.horizontal, IntradaSpacing.card)
    .frame(maxWidth: .infinity, alignment: .leading)
    .faultWash(faulted)
  }

  private var hint: String {
    [FaultMark.spoken(faulted), FieldMark.spoken(readWeakly)]
      .filter { !$0.isEmpty }
      .joined(separator: ". ")
  }
}
