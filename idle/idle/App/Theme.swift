import SwiftUI

enum IdleTheme {
    // MARK: - Colors
    static let amber = Color(red: 1.0, green: 0.702, blue: 0.0)
    static let background = Color.black
    static let surfacePrimary = Color(white: 0.1)
    static let surfaceSecondary = Color(white: 0.15)
    static let surfaceTertiary = Color(white: 0.2)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.6)
    static let textTertiary = Color(white: 0.4)
    static let separator = Color(white: 0.25)

    // MARK: - Typography
    static let titleFont = Font.system(.title2, design: .default, weight: .semibold)
    static let headlineFont = Font.system(.headline, design: .default, weight: .medium)
    static let bodyFont = Font.system(.body, design: .default)
    static let captionFont = Font.system(.caption, design: .default)
}

// MARK: - View Modifiers

struct IdleBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(IdleTheme.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .tint(IdleTheme.amber)
    }
}

extension View {
    func idleBackground() -> some View {
        modifier(IdleBackgroundModifier())
    }
}

// MARK: - Surface Card Style

struct IdleSurface: ViewModifier {
    var level: Int = 1

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(level == 1 ? IdleTheme.surfacePrimary : IdleTheme.surfaceSecondary)
            )
    }
}

extension View {
    func idleSurface(level: Int = 1) -> some View {
        modifier(IdleSurface(level: level))
    }
}
