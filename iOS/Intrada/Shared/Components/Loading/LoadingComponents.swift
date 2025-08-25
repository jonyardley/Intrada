//
//  LoadingComponents.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SwiftUI

// MARK: - Loading Components

/// Reusable loading view component
struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primary))

            Text(message)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.backgroundSecondary)
    }
}

/// Loading overlay for existing content
struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String

    var body: some View {
        ZStack {
            if isLoading {
                Color.clear
                    .background(.ultraThinMaterial)

                VStack(spacing: Theme.Spacing.medium) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(message)
            }
        }
    }
}
