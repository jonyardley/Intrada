import UIKit

/// Where an item's photo bytes live. The core holds only the id (spec decision
/// 1: a blob in GRDB fattens every row read on a table already loaded whole).
/// Nothing here deletes: removing a photo tombstones the id and leaves the
/// bytes (spec decision 2). Reaping is #1442.
enum PhotoFileStore {
  enum Failure: Error, Equatable {
    case couldNotEncode
    /// An id hydrated from GRDB never passes the core's validator again, and
    /// it becomes a path component here.
    case notAPhotoId
  }

  private static let crockford = Set("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

  /// JPEG, not the HEIC the spec first wrote (open question 6, settled
  /// 2026-08-29): the scanner hands back a `UIImage` either way, so neither is
  /// the camera's native format here, and HEIC has no encoder on some simulator
  /// configurations the tests run on.
  private static let quality: CGFloat = 0.8
  /// A page stays readable zoomed at this size, at roughly 400 to 600 KB.
  private static let longestEdge: CGFloat = 2048

  static func url(for photoId: String) throws -> URL {
    guard photoId.count == 26, photoId.allSatisfy(crockford.contains) else {
      throw Failure.notAPhotoId
    }
    return try directory().appendingPathComponent("\(photoId).jpg")
  }

  @discardableResult
  static func write(_ image: UIImage, id photoId: String) throws -> URL {
    guard let data = upright(image).jpegData(compressionQuality: quality) else {
      throw Failure.couldNotEncode
    }
    let destination = try url(for: photoId)
    try data.write(to: destination, options: .atomic)
    return destination
  }

  /// Cached because SwiftUI re-evaluates `State(initialValue:)` on every `init`,
  /// so this ran on the main actor each time the detail screen's body changed.
  /// Nothing invalidates it: every save mints a fresh ulid.
  @MainActor
  static func image(for photoId: String) -> UIImage? {
    if let cached = cache.object(forKey: photoId as NSString) { return cached }
    guard let source = try? url(for: photoId),
      let image = UIImage(contentsOfFile: source.path)
    else { return nil }
    cache.setObject(image, forKey: photoId as NSString)
    return image
  }

  @MainActor
  private static let cache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.countLimit = 4
    return cache
  }()

  private static func directory() throws -> URL {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    let photos = support.appendingPathComponent("photos", isDirectory: true)
    try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
    return photos
  }

  /// In pixels, not points: a 2x or 3x image would otherwise sail past a cap
  /// it is four or nine times over. Always redraws, even under the cap: that
  /// bakes orientation into the pixels, which `jpegData` alone does not (#1686).
  private static func upright(_ image: UIImage) -> UIImage {
    let longest = max(image.size.width, image.size.height) * image.scale
    let ratio = min(1, longestEdge / longest)
    let size = CGSize(
      width: image.size.width * image.scale * ratio,
      height: image.size.height * image.scale * ratio)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
  }
}
