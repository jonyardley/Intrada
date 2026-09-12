import SwiftUI
import Testing
import UIKit

@testable import Intrada

/// The detail column keeps a nav bar for the star and Edit while the list hid
/// its own, so the detail's scaffold started a nav bar lower and the two header
/// rules ended at different heights (#1682). A `UIHostingController` with no
/// window lays out no nav bar at all, so the snapshot reference cannot see this:
/// it only shows up in a real window.
@MainActor
struct LibrarySplitAlignmentTests {
  private static let size = CGSize(width: 1194, height: 834)
  /// Sub-pixel rounding only. The drift this covers was a whole nav bar.
  private static let tolerance: CGFloat = 1

  /// Each column's nav bar height, ordered left to right. A hidden bar reserves
  /// nothing, so it counts as zero rather than being dropped.
  private func navigationBarHeights(selecting id: String?) -> [CGFloat] {
    IntradaFonts.register()
    let vc = UIHostingController(
      rootView: LibrarySplitView(previewSelection: id)
        // The suite hosts on an iPhone, where the split takes its compact
        // branch and lays out no columns at all.
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

    var found: [(minX: CGFloat, height: CGFloat)] = []
    walk(vc.view, root: vc.view, into: &found)
    return found.sorted { $0.minX < $1.minX }.map(\.height)
  }

  private func walk(
    _ view: UIView, root: UIView, into found: inout [(minX: CGFloat, height: CGFloat)]
  ) {
    for subview in view.subviews {
      if subview is UINavigationBar {
        let frame = subview.convert(subview.bounds, to: root)
        found.append((minX: frame.minX, height: subview.isHidden ? 0 : frame.height))
      }
      walk(subview, root: root, into: &found)
    }
  }

  /// Whatever chrome each column carries, both must carry the same amount of
  /// it, or their header rules cannot land on the same line.
  @Test func bothColumnsReserveTheSameTopChrome() {
    let heights = navigationBarHeights(selecting: "piece-1")

    // A traversal that found nothing must fail, not pass vacuously.
    #expect(heights.count == 2, "expected a nav bar per column, found \(heights.count)")

    guard heights.count == 2 else { return }
    #expect(
      abs(heights[0] - heights[1]) <= Self.tolerance,
      "columns reserve different top chrome: list \(heights[0]), detail \(heights[1])")
  }
}
