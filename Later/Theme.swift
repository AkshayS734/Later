import SwiftUI

// MARK: - App Theme

struct Theme {
    
    // MARK: - Colors
    
    static let background = Color("Background") // Define in Assets or use fallback
    static let lockedGradientStart = Color(red: 0.1, green: 0.1, blue: 0.2)
    static let lockedGradientEnd = Color(red: 0.05, green: 0.05, blue: 0.1)
    
    static let unlockedGradientStart = Color(red: 1.0, green: 0.95, blue: 0.8)
    static let unlockedGradientEnd = Color(red: 1.0, green: 0.8, blue: 0.6)
    
    static let accent = Color.cyan
    static let secondaryAccent = Color.pink
    
    // MARK: - Gradients
    
    static var lockedBackground: LinearGradient {
        LinearGradient(
            colors: [lockedGradientStart, lockedGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var unlockedBackground: LinearGradient {
        LinearGradient(
            colors: [unlockedGradientStart, unlockedGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Shadows
    
    static let softShadow = HashableShadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    static let glowShadow = HashableShadow(color: .cyan.opacity(0.5), radius: 15, x: 0, y: 0)
}

struct HashableShadow: Hashable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    var isLocked: Bool
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background {
                if isLocked {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 2
                                )
                        )
                }
            }
    }
}

extension View {
    func capsuleCardStyle(isLocked: Bool) -> some View {
        modifier(CardStyle(isLocked: isLocked))
    }
    
    func glowingText() -> some View {
        self.shadow(color: .cyan.opacity(0.8), radius: 8)
    }
}
