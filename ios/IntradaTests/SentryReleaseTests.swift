import Foundation
import Testing

@testable import Intrada

/// The release lane composes the same string from the shipped .ipa's
/// Info.plist, so the format is the contract between the two (#1553).
struct SentryReleaseTests {
  @Test("the name is bundle id, version and build number")
  func composesTheNameTheReleaseLaneBuilds() {
    #expect(
      SentryRelease.name(bundleId: "com.intrada.native", shortVersion: "0.10.0", buildNumber: "42")
        == "com.intrada.native@0.10.0+42")
  }

  @Test(
    "a missing part yields no name, never a half one",
    arguments: [
      (nil, "0.10.0", "42"),
      ("com.intrada.native", nil, "42"),
      ("com.intrada.native", "0.10.0", nil),
      ("", "0.10.0", "42"),
      ("com.intrada.native", "", "42"),
      ("com.intrada.native", "0.10.0", ""),
    ] as [(String?, String?, String?)])
  func refusesAnIncompletePlist(bundleId: String?, shortVersion: String?, buildNumber: String?) {
    #expect(
      SentryRelease.name(
        bundleId: bundleId, shortVersion: shortVersion, buildNumber: buildNumber) == nil)
  }

  @Test("this build can name itself")
  func namesTheRunningBundle() throws {
    let bundle = Bundle(for: LibraryStore.self)
    let identifier = try #require(bundle.bundleIdentifier)
    let name = try #require(SentryRelease.name(for: bundle))
    #expect(name.hasPrefix("\(identifier)@"))
  }
}
