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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        OnboardingPageView(step: step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut, value: currentStep)

                // Bottom controls
                VStack(spacing: AppTheme.Spacing.xxl) {
                    // Page indicator dots
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            SwiftUI.Capsule()
                                .fill(index == currentStep ? AppTheme.accent : Color(.systemFill))
                                .frame(width: index == currentStep ? 20 : 7, height: 7)
                                .animation(reduceMotion ? nil : .spring(response: 0.4), value: currentStep)
                        }
                    }
                    .accessibilityHidden(true)

                    if currentStep < steps.count - 1 {
                        Button {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.4)) {
                                currentStep += 1
                            }
                        } label: {
                            Text("Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.lg)
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(.rect(cornerRadius: AppTheme.Radius.lg))
                    } else {
                        Button {
                            storageManager.requestNotificationPermissionIfNeeded()
                            withAnimation {
                                hasSeenOnboarding = true
                            }
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.lg)
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(.rect(cornerRadius: AppTheme.Radius.lg))
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xxl)
                .padding(.bottom, AppTheme.Spacing.xxxl)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if currentStep < steps.count - 1 {
                        Button("Skip") {
                            withAnimation { hasSeenOnboarding = true }
                        }
                        .foregroundStyle(AppTheme.secondaryLabel)
                        .font(.subheadline)
                    }
                }
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

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxl) {
            Spacer()

            // Icon in a soft filled circle
            ZStack {
                Circle()
                    .fill(step.iconColor.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: step.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(step.iconColor)
            }
            .accessibilityHidden(true)

            VStack(spacing: AppTheme.Spacing.md) {
                Text(step.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.label)
                    .multilineTextAlignment(.center)

                Text(step.body)
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, AppTheme.Spacing.xl)
            }

            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
