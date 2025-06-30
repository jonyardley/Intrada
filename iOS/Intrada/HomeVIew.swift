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

                Spacer()
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    HomeView(core: Core())
}