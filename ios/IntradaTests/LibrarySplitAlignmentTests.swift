import SwiftUI
import Testing
import UIKit

@testable import Intrada

/// #1682 only shows up in a real window: a windowless `UIHostingController`
/// lays out no nav bar at all, so the snapshot suite cannot catch it.
@MainActor
struct LibrarySplitAlignmentTests {
  private static let size = CGSize(width: 1194, height: 834)
  /// Sub-pixel rounding only. The drift this covers was a whole nav bar.
  private static let tolerance: CGFloat = 1

  private func navigationBarBottomEdges(selecting id: String?) -> [CGFloat] {
    IntradaFonts.register()
    let vc = UIHostingController(
      rootView: LibrarySplitView(previewSelection: id)
        .environment(\.horizontalSizeClass, .regular)
        .environment(Store.previewLibrary)
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.calendar, PreviewCalendar.utc)
        .environment(\.intradaMotionDisabled, true))
    vc.overrideUserInterfaceStyle = .light
    let window = UIWindow(frame: CGRect(origin: .zero, size: Self.size))
    window.rootViewController = vc
    window.isHidden = false
    vc.view.layoutIfNeeded()
    defer { window.rootViewController = nil }

    var found: [(minX: CGFloat, maxY: CGFloat)] = []
    walk(vc.view, root: vc.view, into: &found)
    return found.sorted { $0.minX < $1.minX }.map(\.maxY)
  }

  private func walk(
    _ view: UIView, root: UIView, into found: inout [(minX: CGFloat, maxY: CGFloat)]
  ) {
    for subview in view.subviews {
      if subview is UINavigationBar {
        let frame = subview.convert(subview.bounds, to: root)
        found.append((minX: frame.minX, maxY: subview.isHidden ? 0 : frame.maxY))
      }
      walk(subview, root: root, into: &found)
    }
  }

  @Test func bothColumnsReserveTheSameTopChrome() {
    let edges = navigationBarBottomEdges(selecting: "piece-1")

    // A traversal that found nothing must fail, not pass vacuously.
    #expect(edges.count == 2, "expected a nav bar per column, found \(edges.count)")

    guard edges.count == 2 else { return }
    #expect(
      abs(edges[0] - edges[1]) <= Self.tolerance,
      "columns reserve different top chrome: list \(edges[0]), detail \(edges[1])")
  }

  /// #1681's launch state: nothing selected, so the detail column is bare.
  @Test func bothColumnsReserveTheSameTopChromeWithNoSelection() {
    let edges = navigationBarBottomEdges(selecting: nil)

    #expect(edges.count == 2, "expected a nav bar per column, found \(edges.count)")

    guard edges.count == 2 else { return }
    #expect(
      abs(edges[0] - edges[1]) <= Self.tolerance,
      "columns reserve different top chrome: list \(edges[0]), detail \(edges[1])")
  }
}
