//
//  ContentView.swift
//  Intrada
//
//  Created by Jon Yardley on 15/05/2025.
//

import SharedTypes
import SwiftUI

struct ContentView: View {
    @ObservedObject var core: Core
    
    init(core: Core) {
        self.core = core
        print("🎯 ContentView init called")
    }
  
    var body: some View {
        NavigationStack {
            TabView {
                HomeView(core: core)
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                GoalsView(core: core)
                    .tabItem {
                        Label("Goals", systemImage: "chart.bar.xaxis.ascending.badge.clock")
                    }
                SessionsView(core: core)
                    .tabItem {
                        Label("Sessions", systemImage: "pianokeys")
                    }
                StudiesView(core: core)
                    .tabItem {
                        Label("Studies", systemImage: "music.quarternote.3")
                    }
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
            }
        }
    }
}

#Preview {
    ContentView(core: Core())
}
