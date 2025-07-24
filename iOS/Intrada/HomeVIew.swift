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
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                
                Text("Welcome to Intrada")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.Colors.text)
                    .multilineTextAlignment(.center)

                Text("Let's Rachmaninov")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Theme.Colors.primary)
                    .multilineTextAlignment(.center)

                Spacer()
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    HomeView(core: Core())
}