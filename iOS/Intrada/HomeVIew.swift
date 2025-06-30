//
//  HomeVIew.swift
//  Intrada
//
//  Created by Jon Yardley on 30/05/2025.
//

import SharedTypes
import SwiftUI

struct HomeView: View {
    @ObservedObject var core: Core
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Text("Welcome to Intrada")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text("Let's Rachmaninov")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Color(red: 79/255, green: 70/255, blue: 229/255))
                    .multilineTextAlignment(.center)
                
                // Test Appwrite Integration
                Button("Load Goals from Appwrite") {
                    core.update(Event.loadGoals)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                // Display loaded goals
                if !core.view.goals.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Loaded Goals:")
                            .font(.headline)
                        
                        ForEach(core.view.goals, id: \.id) { goal in
                            VStack(alignment: .leading) {
                                Text(goal.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let description = goal.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()

                Text(core.view.message)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    HomeView(core: Core())
}

