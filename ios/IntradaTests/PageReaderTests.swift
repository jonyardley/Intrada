import IntradaCoreFFI
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

/// The orientation half of cropping a chosen photo (#1436). `toPage` itself is
/// device-only: document segmentation does not run on the simulator.
@MainActor
struct PageCropTests {
  /// A photo taken holding the phone upright is a landscape buffer plus a
  /// `.right` orientation, and `cgImage` hands back the buffer alone.
  private func rotatedPhoto() throws -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    let landscapeBuffer = UIGraphicsImageRenderer(
      size: CGSize(width: 1600, height: 1200), format: format
    ).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1200))
    }
    return UIImage(cgImage: try #require(landscapeBuffer.cgImage), scale: 1, orientation: .right)
  }

  @Test func aRotatedPhotoIsRedrawnUprightBeforeAnythingReadsIt() throws {
    let photo = try rotatedPhoto()
    #expect(photo.size.height > photo.size.width, "the photo is portrait")
    #expect(
      try #require(photo.cgImage).width > #require(photo.cgImage).height,
      "but its buffer is not, which is the whole problem")

    let upright = PageCrop.redrawnUpright(photo)

    #expect(upright.imageOrientation == .up)
    #expect(
      try #require(upright.cgImage).height > #require(upright.cgImage).width,
      "the buffer now matches the page, so Vision reads it the right way up")
  }

  /// The device log on #1565, through the generated binding: the Rust table
  /// proves the rule, this proves the Swift side reaches it.
  @Test func theLoggedOutlineIsRefusedForACornerOnTheFrameEdge() {
    let outline = PageOutline(
      topLeft: Corner(x: 0.0069, y: 0.7891),
      topRight: Corner(x: 1.0, y: 0.8125),
      bottomLeft: Corner(x: 0.2292, y: 0.2461),
      bottomRight: Corner(x: 1.0, y: 0.2695),
      frameWidth: 3024,
      frameHeight: 4032)

    #expect(pageOutlineFault(outline: outline) == .cornerOnFrameEdge)
  }

  /// The keystone only crosses the limit in one aspect ratio, so swapping x
  /// with y, width with height, or any two corners in the mapping flips one
  /// of these answers.
  @Test func everyCornerAndTheFrameReachTheCoreInTheRightField() {
    let keystoned = { (frame: CGSize) in
      PageCrop.outline(
        topLeft: CGPoint(x: 0.12, y: 0.9), topRight: CGPoint(x: 0.88, y: 0.9),
        bottomLeft: CGPoint(x: 0.05, y: 0.1), bottomRight: CGPoint(x: 0.95, y: 0.1),
        frame: frame)
    }

    #expect(
      pageOutlineFault(outline: keystoned(CGSize(width: 4032, height: 500))) == .edgesNotParallel)
    #expect(pageOutlineFault(outline: keystoned(CGSize(width: 3024, height: 4032))) == nil)
  }

  /// The one exit reachable without Vision.
  @Test func aPhotoWithNoBufferComesBackAsTakenAndSaysNoPageWasFound() {
    let photo = UIImage()

    let outcome = PageCrop.toPage(photo)

    #expect(!outcome.pageFound)
    #expect(outcome.image === photo)
  }
}
