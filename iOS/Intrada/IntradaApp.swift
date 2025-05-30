import SwiftUI

@main
struct IntradaApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView(core: Core())
        .accentColor(Color(red: 79/255, green: 70/255, blue: 229/255))
    }
  }
}
