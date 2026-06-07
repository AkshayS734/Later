import SwiftUI

// MARK: - App Design Tokens
//
// Semantic, system-adaptive design system.
// All colors respect Light / Dark mode automatically.
// Typography presets use SF Pro with clear hierarchy.

struct AppTheme {

    // MARK: - Accent

    /// Primary accent — indigo-violet. Premium, modern, distinctive.
    static let accent = Color("AppAccent")

    /// Secondary warm gold — used for unlocked/opened states and celebratory moments.
    static let gold = Color(red: 0.82, green: 0.65, blue: 0.25)

    // MARK: - Semantic State Colors
    static let sealedTint   = Color(.systemIndigo)   // locked capsule
    static let readyTint    = Color(.systemGreen)    // unlocked / ready
    static let surpriseTint = Color(.systemPurple)   // surprise capsule
    static let destructive  = Color(.systemRed)

    // MARK: - Backgrounds  (all system-adaptive)
    static let background          = Color(.systemBackground)
    static let groupedBackground   = Color(.systemGroupedBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground  = Color(.tertiarySystemBackground)

    // MARK: - Text  (system-adaptive)
    static let label          = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let tertiaryLabel  = Color(.tertiaryLabel)
    static let placeholderText = Color(.placeholderText)

    // MARK: - Surfaces / Borders
    static let separator       = Color(.separator)
    static let opaqueSeparator = Color(.opaqueSeparator)

    // MARK: - Spacing Scale (4pt base)
    enum Spacing {
        static let xxs:  CGFloat = 2
        static let xs:   CGFloat = 4
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 20
        static let xxl:  CGFloat = 24
        static let xxxl: CGFloat = 32
        static let xxxxl: CGFloat = 48
    }

    // MARK: - Corner Radii
    enum Radius {
        static let sm:   CGFloat = 8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 20
        static let xxl:  CGFloat = 28
        static let full: CGFloat = 999
    }

    // MARK: - Typography Presets
    enum Typography {
        static let heroTitle   = Font.largeTitle.weight(.bold)
        static let screenTitle = Font.title.weight(.bold)
        static let sectionTitle = Font.title3.weight(.bold)
        static let cardTitle   = Font.headline
        static let body        = Font.body
        static let caption     = Font.caption
        static let captionBold = Font.caption.weight(.semibold)
        static let overline    = Font.caption2.weight(.semibold)
    }

    // MARK: - Elevation Shadows
    enum Elevation {
        static func small(colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
            colorScheme == .dark
                ? (Color.black.opacity(0.5), 4, 2)
                : (Color.black.opacity(0.06), 4, 2)
        }

        static func medium(colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
            colorScheme == .dark
                ? (Color.black.opacity(0.5), 10, 5)
                : (Color.black.opacity(0.08), 8, 4)
        }

        static func large(colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
            colorScheme == .dark
                ? (Color.black.opacity(0.6), 20, 10)
                : (Color.black.opacity(0.1), 16, 8)
        }
    }

    // Backward compat
    static func cardShadow(colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        Elevation.medium(colorScheme: colorScheme)
    }
}

// MARK: - Locked / Unlocked Screen Backgrounds

extension AppTheme {

    /// Deep midnight gradient — sealed vault, mystery, anticipation.
    static var lockedBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.06, blue: 0.16),
                Color(red: 0.02, green: 0.02, blue: 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Warm cream-to-white — revealed letter, golden hour warmth.
    static var unlockedBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.97, blue: 0.93),
                Color(red: 0.96, green: 0.92, blue: 0.83)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Extensions

extension View {

    /// Glassmorphic card — frosted glass with subtle border.
    func glassCard(cornerRadius: CGFloat = AppTheme.Radius.xl) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
    }

    /// Frosted surface — lighter material for cards on grouped backgrounds.
    func frostedSurface(cornerRadius: CGFloat = AppTheme.Radius.lg) -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
    }

    /// Applies the standard capsule list card background.
    func capsuleCardBackground(colorScheme: ColorScheme) -> some View {
        let shadow = AppTheme.cardShadow(colorScheme: colorScheme)
        return self.background {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
        }
    }

    /// Subtle colored glow behind a view.
    func subtleGlow(color: Color, radius: CGFloat = 20) -> some View {
        self.background(
            Circle()
                .fill(color.opacity(0.15))
                .blur(radius: radius)
        )
    }
}
