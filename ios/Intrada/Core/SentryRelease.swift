import Foundation

/// The name a crash arrives under, pinned rather than left to the SDK default
/// so the release lane can compose the same string off the shipped .ipa (#1553).
enum SentryRelease {
  static func name(bundleId: String?, shortVersion: String?, buildNumber: String?) -> String? {
    guard let bundleId, !bundleId.isEmpty,
      let shortVersion, !shortVersion.isEmpty,
      let buildNumber, !buildNumber.isEmpty
    else { return nil }
    return "\(bundleId)@\(shortVersion)+\(buildNumber)"
  }

  static func name(for bundle: Bundle) -> String? {
    name(
      bundleId: bundle.bundleIdentifier,
      shortVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
      buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
  }
}
