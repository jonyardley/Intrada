import SwiftUI

// MARK: - Theme System
struct Theme {
    static let shared = Theme()
    
    private init() {}
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color(red: 79/255, green: 70/255, blue: 229/255)
        static let secondary = Color.blue
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let text = Color.primary
        static let textSecondary = Color.gray
        static let background = Color.gray.opacity(0.1)
        static let backgroundSecondary = Color.gray.opacity(0.05)
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.semibold)
        static let headline = Font.headline
        static let subheadline = Font.subheadline
        static let body = Font.body
        static let caption = Font.caption
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let card = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let button = Shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Shadow Helper
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        self
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.background)
            .cornerRadius(Theme.CornerRadius.lg)
    }
    
    func primaryButtonStyle() -> some View {
        self
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.primary)
            .cornerRadius(Theme.CornerRadius.md)
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .foregroundColor(Theme.Colors.primary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Colors.primary.opacity(0.1))
            .cornerRadius(Theme.CornerRadius.sm)
    }
    
    func badgeStyle(color: Color) -> some View {
        self
            .font(Theme.Typography.caption)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(Theme.CornerRadius.md)
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