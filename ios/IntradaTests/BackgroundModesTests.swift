import Foundation
import Testing

/// The partial plist under `GENERATE_INFOPLIST_FILE` drops custom keys silently (#1399).
struct BackgroundModesTests {
  @Test func theAppDeclaresAudioAsABackgroundMode() {
    let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
    #expect(modes == ["audio"])
  }
}
