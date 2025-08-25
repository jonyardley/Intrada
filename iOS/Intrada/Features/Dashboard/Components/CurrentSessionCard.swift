//
//  CurrentSessionCard.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SharedTypes
import SwiftUI

// MARK: - Current Session Card

struct CurrentSessionCard: View {
    let session: PracticeSession
    @ObservedObject var core: Core

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.Spacing.extraSmall) {
                        Text("Current Session")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.textSecondary)

                        Text(session.intention)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.text)
                    }

                    Spacer()

                    // Live timer
                    if case .started = session.state {
                        DynamicTimerView(
                            session: session,
                            fontSize: .title3,
                            textColor: Theme.Colors.primary
                        )
                    }
                }

                // Quick action to go to active session
                NavigationLink(destination: ActiveSessionDetailView(core: core, sessionId: session.id)) {
                    HStack {
                        Text("Continue Session")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.large)
    }
}
