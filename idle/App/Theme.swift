import SwiftUI

extension Color {
    /// idle's signature amber accent — like an engine idling indicator light.
    static let idleAmber = Color(red: 0.93, green: 0.69, blue: 0.13)

    /// Slightly muted amber for secondary elements.
    static let idleAmberMuted = Color(red: 0.93, green: 0.69, blue: 0.13).opacity(0.6)

    /// Dark surface background.
    static let idleSurface = Color(red: 0.09, green: 0.09, blue: 0.10)

    /// Slightly elevated surface for cards.
    static let idleCard = Color(red: 0.13, green: 0.13, blue: 0.14)

    /// Subtle border/divider color.
    static let idleBorder = Color.white.opacity(0.08)
}

extension Font {
    /// Large title for prominent headers.
    static let idleTitle = Font.system(size: 28, weight: .bold, design: .default)

    /// Section headers.
    static let idleHeadline = Font.system(size: 17, weight: .semibold, design: .default)

    /// Body text.
    static let idleBody = Font.system(size: 15, weight: .regular, design: .default)

    /// Caption text.
    static let idleCaption = Font.system(size: 12, weight: .regular, design: .default)
}
