//
//  Headers.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SharedTypes
import SwiftUI

// MARK: - List Header Component

struct ListHeader: View {
    let title: String
    let onAddTapped: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.Typography.largeTitle)

            Spacer()

            Button(action: onAddTapped) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundColor(Theme.Colors.primary)
            }
        }
        .padding(.horizontal, Theme.Spacing.large)
    }
}

// MARK: - Section Header Component

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(Theme.Typography.title2)
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.top, Theme.Spacing.large)
    }
}

// MARK: - Empty State Component

struct EmptyStateView: View {
    let message: String

    var body: some View {
        Text(message)
            .foregroundColor(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.large)
    }
}
