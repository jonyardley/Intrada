import CoreImage
import UIKit
import Vision
import os

/// Crops a photographed page out of whatever it was lying on and flattens the
/// perspective, as the scanner does for its own route. Vision reads text out of
/// the surround, and that competes with the real title (#1436).
enum PageCrop {
  enum Outcome: Sendable {
    case flattened(UIImage)
    /// Never lose the photo: the original comes back whenever no page is found.
    case asTaken(UIImage)

    var image: UIImage {
      switch self {
      case .flattened(let page), .asTaken(let page): page
      }
    }

    var pageFound: Bool {
      if case .flattened = self { return true }
      return false
    }
  }

  /// Which exit returned the original. Every one of them was silent, and a
  /// device run has to be able to say which one fires (#1565).
  private enum Miss: String {
    case noBuffer = "no-buffer"
    case visionFailed = "vision-failed"
    case noPage = "no-page"
    case noCorrection = "no-correction"
    case renderFailed = "render-failed"
  }

  /// One context, not one per photo: it spins up a Metal command queue.
  private static let context = CIContext()
  private static let log = Logger(subsystem: "com.intrada.native", category: "page-crop")

  static func toPage(_ image: UIImage) -> Outcome {
    // `cgImage` is the raw buffer with the EXIF rotation split off into
    // `imageOrientation`, and both Vision and CoreImage below assume `.up`.
    // A portrait photo would otherwise be cropped, stored and read sideways.
    let upright = image.imageOrientation == .up ? image : redrawnUpright(image)
    guard let cgImage = upright.cgImage else { return missed(image, .noBuffer) }

    let request = VNDetectDocumentSegmentationRequest()
    do {
      try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
    } catch {
      log.notice("vision error: \(String(describing: error), privacy: .public)")
      return missed(image, .visionFailed)
    }
    guard let page = request.results?.first else { return missed(image, .noPage) }

    let source = CIImage(cgImage: cgImage)
    let extent = source.extent
    log.notice(
      """
      page in \(Int(extent.width), privacy: .public)x\(Int(extent.height), privacy: .public) \
      confidence \(page.confidence, privacy: .public) \
      tl \(page.topLeft.debugDescription, privacy: .public) \
      tr \(page.topRight.debugDescription, privacy: .public) \
      bl \(page.bottomLeft.debugDescription, privacy: .public) \
      br \(page.bottomRight.debugDescription, privacy: .public)
      """)

    func point(_ normalised: CGPoint) -> CIVector {
      CIVector(x: normalised.x * extent.width, y: normalised.y * extent.height)
    }

    guard
      let corrected = CIFilter(
        name: "CIPerspectiveCorrection",
        parameters: [
          kCIInputImageKey: source,
          "inputTopLeft": point(page.topLeft),
          "inputTopRight": point(page.topRight),
          "inputBottomLeft": point(page.bottomLeft),
          "inputBottomRight": point(page.bottomRight),
        ])?.outputImage
    else {
      return missed(image, .noCorrection)
    }
    guard let rendered = context.createCGImage(corrected, from: corrected.extent) else {
      return missed(image, .renderFailed)
    }

    log.notice(
      "flattened to \(rendered.width, privacy: .public)x\(rendered.height, privacy: .public)")
    return .flattened(UIImage(cgImage: rendered))
  }

  private static func missed(_ image: UIImage, _ miss: Miss) -> Outcome {
    log.notice("kept the photo as taken: \(miss.rawValue, privacy: .public)")
    return .asTaken(image)
  }

  /// Internal so it is testable without Vision, which `toPage` is not.
  static func redrawnUpright(_ image: UIImage) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = image.scale
    return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
  }
}
