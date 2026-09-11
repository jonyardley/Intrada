import Testing
import UIKit

@testable import Intrada

/// An unresolved PostScript name falls back to the system font silently (#1676).
struct IntradaFontTests {
  @Test(arguments: [
    IntradaFont.Hanken.regular, IntradaFont.Hanken.medium, IntradaFont.Hanken.semibold,
    IntradaFont.Hanken.bold, IntradaFont.Mono.regular,
  ])
  func bundledFaceResolves(_ name: String) {
    IntradaFonts.register()
    #expect(UIFont(name: name, size: 16) != nil)
  }

  @Test(arguments: [
    IntradaFont.Hanken.medium, IntradaFont.Hanken.semibold, IntradaFont.Hanken.bold,
  ])
  func weightedFaceIsHeavierThanRegular(_ name: String) throws {
    IntradaFonts.register()
    let regular = try #require(UIFont(name: IntradaFont.Hanken.regular, size: 16))
    let weighted = try #require(UIFont(name: name, size: 16))
    #expect(width("Clair de Lune", in: weighted) > width("Clair de Lune", in: regular))
  }

  private func width(_ text: String, in font: UIFont) -> CGFloat {
    (text as NSString).size(withAttributes: [.font: font]).width
  }
}
