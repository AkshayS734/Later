import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @EnvironmentObject var storageManager: StorageManager
    @State private var currentStep = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "clock.badge.plus",
            iconColor: Color(.systemIndigo),
            title: "Welcome to Later",
            body: "Reclaim the joy of anticipation. In a world of instant gratification, some memories are worth waiting for."
        ),
        OnboardingStep(
            icon: "lock.fill",
            iconColor: Color(.systemOrange),
            title: "Seal Your Memories",
            body: "Write a note, attach a photo or video, and lock it away. It stays hidden until the exact date you choose."
        ),
        OnboardingStep(
            icon: "bell.badge.fill",
            iconColor: Color(.systemGreen),
            title: "Stay Notified",
            body: "We'll let you know the moment your capsule is ready to open. Enable notifications so you never miss a memory."
        )
    ]

    // Animated background gradient colors per step
    private var backgroundGradient: LinearGradient {
        let colors: [Color] = {
            switch currentStep {
            case 0: return [Color(red: 0.08, green: 0.06, blue: 0.22), Color(red: 0.04, green: 0.03, blue: 0.12)]
            case 1: return [Color(red: 0.14, green: 0.06, blue: 0.20), Color(red: 0.06, green: 0.03, blue: 0.10)]
            default: return [Color(red: 0.05, green: 0.10, blue: 0.16), Color(red: 0.03, green: 0.05, blue: 0.08)]
            }
        }()
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            // Animated background
            backgroundGradient
                .ignoresSafeArea()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: currentStep)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentStep < steps.count - 1 {
                        Button("Skip") {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                hasSeenOnboarding = true
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.trailing, AppTheme.Spacing.xxl)
                        .padding(.top, AppTheme.Spacing.md)
                    }
                }
                .frame(height: 44)

                // Page content
                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        OnboardingPageView(step: step, isActive: index == currentStep)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: currentStep)

                // Bottom controls
                VStack(spacing: AppTheme.Spacing.xxl) {
                    // Page indicators
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            let isActive = index == currentStep
                            Circle()
                                .fill(isActive ? AppTheme.accent : .white.opacity(0.25))
                                .frame(width: isActive ? 10 : 8, height: isActive ? 10 : 8)
                                .shadow(color: isActive ? AppTheme.accent.opacity(0.5) : .clear, radius: 6)
                                .animation(reduceMotion ? nil : .spring(response: 0.35), value: currentStep)
                        }
                    }
                    .accessibilityHidden(true)

                    // CTA
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if currentStep < steps.count - 1 {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8)) {
                                currentStep += 1
                            }
                        } else {
                            storageManager.requestNotificationPermissionIfNeeded()
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                hasSeenOnboarding = true
                            }
                        }
                    } label: {
                        Text(currentStep < steps.count - 1 ? "Continue" : "Get Started")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.06, green: 0.06, blue: 0.16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.lg)
                            .background(.white, in: RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
                            .shadow(color: .white.opacity(0.15), radius: 12, y: 4)
                    }
                    .contentTransition(.interpolate)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: currentStep)
                }
                .padding(.horizontal, AppTheme.Spacing.xxl)
                .padding(.bottom, AppTheme.Spacing.xxxxl)
            }
        }
    }
}

// MARK: - Step Data

struct OnboardingStep {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
}

// MARK: - Page View

struct OnboardingPageView: View {
    let step: OnboardingStep
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxxl) {
            Spacer()

            // Icon with glow ring
            ZStack {
                // Outer glow
                Circle()
                    .fill(step.iconColor.opacity(0.08))
                    .frame(width: 140, height: 140)

                // Inner circle
                Circle()
                    .fill(step.iconColor.opacity(0.15))
                    .frame(width: 110, height: 110)

                Image(systemName: step.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(step.iconColor)
                    .symbolEffect(.pulse.wholeSymbol, options: .repeating.speed(0.5), isActive: isActive && !reduceMotion)
            }
            .accessibilityHidden(true)

            VStack(spacing: AppTheme.Spacing.md) {
                Text(step.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(step.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, AppTheme.Spacing.xxl)
            }

            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
