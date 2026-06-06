import SwiftUI

// MARK: - App Design Tokens
//
// All colors are semantic and adapt to Light / Dark mode automatically.
// No hardcoded RGB values. Raw literals (cyan, orange) only appear where
// they express a specific, intentional meaning (e.g., state tints).

struct AppTheme {

    // MARK: - Accent
    // Warm amber — evokes time, nostalgia, warmth. Set as the global tint.
    static let accent = Color("AppAccent")

    // MARK: - Semantic State Colors
    static let sealedTint  = Color(.systemOrange)  // locked capsule
    static let readyTint   = Color(.systemGreen)   // unlocked / ready
    static let surpriseTint = Color(.systemPurple) // surprise capsule
    static let destructive = Color(.systemRed)

    // MARK: - Backgrounds  (all system-adaptive)
    static let background         = Color(.systemBackground)
    static let groupedBackground  = Color(.systemGroupedBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground  = Color(.tertiarySystemBackground)

    // MARK: - Text  (system-adaptive)
    static let label          = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let tertiaryLabel  = Color(.tertiaryLabel)
    static let placeholderText = Color(.placeholderText)

    // MARK: - Surfaces / Borders
    static let separator      = Color(.separator)
    static let opaqueSeparator = Color(.opaqueSeparator)

    // MARK: - Spacing Scale (8pt grid)
    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radii
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    // MARK: - Shadows
    // Kept subtle — elevation should be implied, not shouted.
    static func cardShadow(colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        colorScheme == .dark
            ? (Color.black.opacity(0.4), 8, 4)
            : (Color.black.opacity(0.08), 6, 3)
    }
}

// MARK: - Locked / Unlocked Screen Backgrounds
//
// These are the ONE place we intentionally use a custom background
// to create a distinct emotional context for each app state.
// They respect ColorScheme and remain HIG-compliant.

extension AppTheme {

    /// The detail screen background while a capsule is sealed.
    static var lockedBackground: some ShapeStyle {
        // Deep navy gradient — evokes mystery and sealed time.
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.09, blue: 0.18),
                Color(red: 0.04, green: 0.04, blue: 0.09)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The detail screen background when a capsule has been opened.
    static var unlockedBackground: some ShapeStyle {
        // Warm parchment — evokes a revealed letter, golden hour.
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.96, blue: 0.84),
                Color(red: 1.0, green: 0.87, blue: 0.65)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Applies the standard capsule list card background.
    func capsuleCardBackground(colorScheme: ColorScheme) -> some View {
        let shadow = AppTheme.cardShadow(colorScheme: colorScheme)
        return self.background {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
        }
    }
}
