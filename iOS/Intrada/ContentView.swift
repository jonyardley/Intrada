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
        NavigationStack {
            TabView {
                GoalsView(core: core)
                    .tabItem {
                        Label("Goals", systemImage: "target")
                    }
                SessionsView(core: core)
                    .tabItem {
                        Label("Sessions", systemImage: "pianokeys")
                    }
                ExercisesView(core: core)
                    .tabItem {
                        Label("Exercises", systemImage: "music.quarternote.3")
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
