import SharedTypes
import SwiftUI

/// The "where" half of a refused save: the banner carries the core's sentence
/// and the field, row or section it named carries this (#1595). Everything here
/// is a place, never a second verdict: the wording stays the core's.
enum FaultMark {
  static let hint = "The message at the top of the form is about this"

  static func spoken(_ faulted: Bool) -> String {
    faulted ? hint : ""
  }

  /// A staged row is collapsed to its title, so nothing inside it can be
  /// marked; naming the field gives a screen reader the pointer the wash gives
  /// everyone else.
  static func spoken(row field: FormErrorField?) -> String {
    guard let field else { return hint }
    return "\(name(field)). \(hint)"
  }

  static func spoken(bar number: UInt64?) -> String {
    guard let number else { return hint }
    return "Bar \(number). \(hint)"
  }

  static func name(_ field: FormErrorField) -> String {
    switch field {
    case .title: "Title"
    case .composer: "Composer"
    case .tempo: "Tempo"
    case .notes: "Notes"
    case .tags: "Tags"
    }
  }
}

/// Where the form scrolls when a refused save marks something below the fold: a
/// mark the musician cannot see is no better than the banner on its own (#1595).
enum FormAnchor: Hashable {
  case field(FormErrorField)
  case chart
  case row(Int)

  init?(_ target: FormErrorTarget?) {
    switch target {
    case .piece(let field): self = .field(field)
    case .chart, .chartBar: self = .chart
    case .exercise(let index, _): self = .row(Int(index))
    // The profile screen (#1692) marks its own fields; the item form has no anchor for it.
    case .profile, nil: return nil
    }
  }
}

extension View {
  /// `over` keeps the component's own fill for the unmarked case: some of them
  /// need an opaque one to reveal a suggestion list behind.
  func faultWash(_ faulted: Bool, over fill: Color = .clear) -> some View {
    background(faulted ? IntradaColor.dangerWash : fill)
  }
}
