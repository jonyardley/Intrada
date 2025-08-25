//
//  QuickActionsView.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SharedTypes
import SwiftUI

// MARK: - Quick Actions View

struct QuickActionsView: View {
    @ObservedObject var core: Core
    let onQuickStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text("Quick Actions")
                .font(Theme.Typography.title2)
                .padding(.horizontal, Theme.Spacing.large)

            HStack(spacing: Theme.Spacing.medium) {
                // Quick Start Session
                Button(action: onQuickStart) {
                    VStack(spacing: Theme.Spacing.small) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Colors.primary)

                        Text("Quick Start")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.large)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.CornerRadius.large)
                }
                .buttonStyle(PlainButtonStyle())

                // View Sessions
                NavigationLink(destination: SessionsView(core: core)) {
                    VStack(spacing: Theme.Spacing.small) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Colors.primary)

                        Text("Sessions")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.large)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.CornerRadius.large)
                }
                .buttonStyle(PlainButtonStyle())

                // View Goals
                NavigationLink(destination: GoalsView(core: core)) {
                    VStack(spacing: Theme.Spacing.small) {
                        Image(systemName: "target")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.Colors.primary)

                        Text("Goals")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.large)
                    .background(Theme.Colors.background)
                    .cornerRadius(Theme.CornerRadius.large)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, Theme.Spacing.large)
        }
    }
}
