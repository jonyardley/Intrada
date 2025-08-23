import SharedTypes
import SwiftUI

// MARK: - Generic Card Component

struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .cardStyle()
    }
}

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

// MARK: - Enhanced Date and Time Formatting

extension DateFormatter {
    static let iso8601 = ISO8601DateFormatter()

    static func formatDateAndTime(_ dateString: String) -> String {
        if let date = iso8601.date(from: dateString) {
            let calendar = Calendar.current
            let displayFormatter = DateFormatter()

            if calendar.isDateInToday(date) {
                displayFormatter.dateFormat = "'Today at' h:mm a"
            } else if calendar.isDateInYesterday(date) {
                displayFormatter.dateFormat = "'Yesterday at' h:mm a"
            } else {
                displayFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
            }
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Generic Row Component

struct GenericRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Theme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.background)
            .cornerRadius(Theme.CornerRadius.large)
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    let style: ActionButtonStyle

    enum ActionButtonStyle {
        case primary
        case secondary
        case destructive
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.extraSmall) {
                Image(systemName: systemImage)
                Text(title)
            }
        }
        .buttonStyle(buttonStyle)
    }

    private var buttonStyle: AnyButtonStyle {
        switch style {
        case .primary:
            AnyButtonStyle(PrimaryButtonStyle())
        case .secondary:
            AnyButtonStyle(SecondaryButtonStyle())
        case .destructive:
            AnyButtonStyle(DestructiveButtonStyle())
        }
    }
}

// MARK: - Type-erased Button Style

struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init(_ style: some ButtonStyle) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// MARK: - Destructive Button Style

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.small)
            .background(Theme.Colors.error)
            .cornerRadius(Theme.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
