//
//  StatsOverviewView.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SharedTypes
import SwiftUI

// MARK: - Stats Overview View

struct StatsOverviewView: View {
    let activeSessions: [PracticeSession]
    let completedSessions: [PracticeSession]
    let goalsCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("Your Progress")
                .font(Theme.Typography.title2)
                .padding(.horizontal, Theme.Spacing.large)

            HStack(spacing: Theme.Spacing.medium) {
                // Active Sessions Count
                StatCard(
                    title: "Active",
                    value: "\(activeSessions.count)",
                    subtitle: "sessions",
                    color: Theme.Colors.primary
                )

                // Completed Sessions Count
                StatCard(
                    title: "Completed",
                    value: "\(completedSessions.count)",
                    subtitle: "sessions",
                    color: Theme.Colors.success
                )

                // Goals Count
                StatCard(
                    title: "Goals",
                    value: "\(goalsCount)",
                    subtitle: "total",
                    color: Theme.Colors.secondary
                )
            }
            .padding(.horizontal, Theme.Spacing.large)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.extraSmall) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)

            Text(value)
                .font(Theme.Typography.title)
                .foregroundColor(color)

            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.medium)
        .background(Theme.Colors.background)
        .cornerRadius(Theme.CornerRadius.large)
    }
}
