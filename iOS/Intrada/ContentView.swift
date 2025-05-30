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
  
    var body: some View {
        NavigationStack {
            TabView {
                GoalsView(core: core)
                    .tabItem {
                        Label("Goals", systemImage: "florinsign.gauge.chart.leftthird.topthird.rightthird")
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
