import Foundation

/// The name a crash arrives under. Pinned here rather than left to the Sentry
/// SDK's default so the release the TestFlight lane creates cannot drift from
/// the one the app reports: both compose these three Info.plist keys, and a
/// mismatch would leave every beta crash unattributed (#1553).
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
