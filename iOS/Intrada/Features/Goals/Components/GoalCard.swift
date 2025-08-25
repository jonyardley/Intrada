//
//  GoalCard.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SharedTypes
import SwiftUI

struct GoalCard: View {
    let goal: PracticeGoal

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text(goal.name)
                    .font(Theme.Typography.headline)

                if let description = goal.description {
                    Text(description)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                }

                HStack {
                    if let targetDate = goal.targetDate {
                        DateStatusView(targetDate: targetDate)
                    }

                    Spacer()

                    StatusBadge(status: goal.status)
                }
            }
        }
    }
}
