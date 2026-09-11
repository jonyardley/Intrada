import SharedTypes
import Testing
import UIKit

@testable import Intrada

/// Vision against a page we drew ourselves. The core's heuristics are tested in
/// Rust with no device; what can only be checked here is that the shell hands
/// the core the geometry it promised — Vision normalises from the bottom left
/// and `RecognisedLine` is documented top-left.
@MainActor
struct PageReaderTests {
  private func discard(_ photoId: String) {
    guard let url = try? PhotoFileStore.url(for: photoId) else { return }
    try? FileManager.default.removeItem(at: url)
  }

  /// A title band across the top and a credit line below it, at known heights.
  private func page(title: String, credit: String) -> UIImage {
    let size = CGSize(width: 1000, height: 1400)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      title.draw(
        at: CGPoint(x: 80, y: 90),
        withAttributes: [.font: UIFont.systemFont(ofSize: 96), .foregroundColor: UIColor.black])
      credit.draw(
        at: CGPoint(x: 80, y: 1180),
        withAttributes: [.font: UIFont.systemFont(ofSize: 40), .foregroundColor: UIColor.black])
    }
  }

  private func lines(from output: RecognitionOutput) throws -> [RecognisedLine] {
    guard case .page(let reading) = output else {
      Issue.record("expected a page reading, got \(output)")
      return []
    }
    return reading.lines
  }

  @Test func readsTheTextOnAPage() async throws {
    let photoId = Ulid.generate()
    defer { discard(photoId) }
    try PhotoFileStore.write(page(title: "Autumn Leaves", credit: "Music by Kosma"), id: photoId)

    let read = try lines(from: await PageReader.read(photoId: photoId))

    #expect(read.contains { $0.text.contains("Autumn") })
    #expect(read.contains { $0.text.contains("Kosma") })
  }

  /// The whole reason the shell flips the origin: `read_fields` calls the top
  /// of the page `y` near 0, and picks the title out of that band. Drop the
  /// flip and the title reads as the bottom of the page.
  @Test func geometryIsNormalisedFromTheTopLeft() async throws {
    let photoId = Ulid.generate()
    defer { discard(photoId) }
    try PhotoFileStore.write(page(title: "Autumn Leaves", credit: "Music by Kosma"), id: photoId)

    let read = try lines(from: await PageReader.read(photoId: photoId))
    let title = try #require(read.first { $0.text.contains("Autumn") })
    let credit = try #require(read.first { $0.text.contains("Kosma") })

    #expect(title.y < 0.4, "the title sits in the band read_fields looks in")
    #expect(credit.y > title.y, "the credit is printed below the title")
  }

  /// The title is set at more than twice the credit's point size, and
  /// `read_fields` picks the title by exactly this.
  @Test func lineHeightTracksThePrintedTextSize() async throws {
    let photoId = Ulid.generate()
    defer { discard(photoId) }
    try PhotoFileStore.write(page(title: "Autumn Leaves", credit: "Music by Kosma"), id: photoId)

    let read = try lines(from: await PageReader.read(photoId: photoId))
    let title = try #require(read.first { $0.text.contains("Autumn") })
    let credit = try #require(read.first { $0.text.contains("Kosma") })

    #expect(title.height > credit.height)
  }

  /// Phase A leaves bytes on disk but the core can still name an id nothing was
  /// written for. That is `Failed`, never an empty page that reads as a blank.
  @Test func anIdWithNoBytesFails() async {
    let output = await PageReader.read(photoId: Ulid.generate())
    #expect(output == .failed)
  }
}
