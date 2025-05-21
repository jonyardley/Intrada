//
//  ContentView.swift
//  Intrada
//
//  Created by Jon Yardley on 15/05/2025.
//

import SwiftUI
import SharedTypes

struct ContentView: View {
    @ObservedObject var core: Core
  
  var body: some View {
    TabView {
      HomeView(core: core)
        .tabItem {
          Label("Home", systemImage: "house")
        }

      SearchView()
        .tabItem {
          Label("Search", systemImage: "magnifyingglass")
        }

      ProfileView()
        .tabItem {
          Label("Profile", systemImage: "person")
        }
    }
  }
}

#Preview {
  ContentView(core: Core())
}
