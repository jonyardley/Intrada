import SwiftUI

// MARK: - Theme System

struct Theme {
    static let shared = Theme()

    private init() {}

    // MARK: - Colors

    enum Colors {
        static let primary = Color(red: 79 / 255, green: 70 / 255, blue: 229 / 255)
        static let secondary = Color.blue
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let text = Color.primary
        static let textSecondary = Color.gray
        static let textTertiary = Color.gray.opacity(0.6)
        static let background = Color.gray.opacity(0.1)
        static let backgroundSecondary = Color.gray.opacity(0.05)
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.semibold)
        static let headline = Font.headline
        static let subheadline = Font.subheadline
        static let body = Font.body
        static let caption = Font.caption
    }

    // MARK: - Spacing

    enum Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let extraExtraLarge: CGFloat = 24

    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 10
        static let extraLarge: CGFloat = 12
    }

    // MARK: - Shadows

    enum Shadows {
        static let card = Shadow(color: .black.opacity(0.1), radius: 2, xOffset: 0, yOffset: 1)
        static let button = Shadow(color: .black.opacity(0.2), radius: 4, xOffset: 0, yOffset: 2)
    }
}

// MARK: - Shadow Helper

struct Shadow {
    let color: Color
    let radius: CGFloat
    let xOffset: CGFloat
    let yOffset: CGFloat
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        padding(Theme.Spacing.medium)
            .background(Theme.Colors.background)
            .cornerRadius(Theme.CornerRadius.large)
    }

    func primaryButtonStyle() -> some View {
        foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.small)
            .background(Theme.Colors.primary)
            .cornerRadius(Theme.CornerRadius.medium)
    }

    func secondaryButtonStyle() -> some View {
        foregroundColor(Theme.Colors.primary)
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.extraSmall)
            .background(Theme.Colors.primary.opacity(0.1))
            .cornerRadius(Theme.CornerRadius.small)
    }

    func badgeStyle(color: Color) -> some View {
        font(Theme.Typography.caption)
            .padding(.horizontal, Theme.Spacing.small)
            .padding(.vertical, Theme.Spacing.extraSmall)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(Theme.CornerRadius.medium)
    }
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .primaryButtonStyle()
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .secondaryButtonStyle()
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
