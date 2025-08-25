//
//  StatusBadges.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SharedTypes
import SwiftUI

// MARK: - Status Badge Component

struct StatusBadge: View {
    let status: GoalStatus

    var body: some View {
        Text(statusText)
            .badgeStyle(color: statusColor)
    }

    private var statusColor: Color {
        switch status {
        case .notStarted:
            Theme.Colors.textSecondary
        case .inProgress:
            Theme.Colors.secondary
        case .completed:
            Theme.Colors.success
        }
    }

    private var statusText: String {
        switch status {
        case .notStarted:
            "Not Started"
        case .inProgress:
            "In Progress"
        case .completed:
            "Completed"
        }
    }
}

// MARK: - Date Status Component

struct DateStatusView: View {
    let targetDate: String

    var body: AnyView {
        let calendar = Calendar.current
        let today = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        if let targetDateObj = dateFormatter.date(from: targetDate) {
            let components = calendar.dateComponents([.day], from: today, to: targetDateObj)
            if let days = components.day {
                let isOverdue = days < 0
                let color = isOverdue ? Theme.Colors.error : Theme.Colors.primary
                let text = isOverdue ? "\(targetDate) - \(abs(days)) days ago" : "\(targetDate) - \(days) days to go"

                return AnyView(HStack(spacing: Theme.Spacing.extraSmall) {
                    Image(systemName: "calendar")
                        .foregroundColor(color)
                    Text(text)
                        .font(Theme.Typography.caption)
                        .foregroundColor(isOverdue ? Theme.Colors.error : Theme.Colors.textSecondary)
                })
            } else {
                return AnyView(invalidDateView)
            }
        } else {
            return AnyView(invalidDateView)
        }
    }

    private var invalidDateView: some View {
        HStack(spacing: Theme.Spacing.extraSmall) {
            Image(systemName: "calendar")
                .foregroundColor(Theme.Colors.textSecondary)
            Text("Invalid date")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
        }
    }
}
