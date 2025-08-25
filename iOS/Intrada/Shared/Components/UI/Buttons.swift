//
//  Buttons.swift
//  Intrada
//
//  Created by Assistant on 25/08/2025.
//

import SharedTypes
import SwiftUI

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
