import SwiftUI
import SwiftData
import Combine
import WidgetKit

struct CapsuleListView: View {
    @EnvironmentObject var storageManager: StorageManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Capsule.unlockDate) private var capsules: [Capsule]

    @State private var showingCreationSheet = false
    @State private var showingSettingsSheet = false
    @State private var now = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if capsules.isEmpty {
                        emptyState
                    } else {
                        capsuleList
                    }
                }

                // Floating "New Memory" CTA
                floatingCTA
            }
            .navigationTitle("Time Capsules")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.medium)
                            .accessibilityLabel("Settings")
                    }
                }
            }
            .sheet(isPresented: $showingCreationSheet) {
                CapsuleCreationView()
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
            .onReceive(refreshTimer) { date in
                now = date
            }
            .onAppear { now = Date() }
        }
    }

    // MARK: - Floating CTA

    private var floatingCTA: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showingCreationSheet = true
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
                Text("New Memory")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.xxl)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.accent, in: SwiftUI.Capsule())
            .shadow(color: AppTheme.accent.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .padding(.bottom, AppTheme.Spacing.lg)
        .accessibilityLabel("Create new memory capsule")
    }

    // MARK: - Capsule List

    private var capsuleList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {

                // Ready to Open
                if !unlockedCapsules.isEmpty {
                    sectionHeader(title: "Ready to Open", icon: "lock.open.fill", color: AppTheme.readyTint)

                    ForEach(unlockedCapsules) { capsule in
                        NavigationLink(destination: CapsuleDetailView(capsule: capsule)) {
                            CapsuleRow(capsule: capsule, isLocked: false, now: now, colorScheme: colorScheme)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteCapsule(capsule)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Spacer().frame(height: AppTheme.Spacing.xxl)
                }

                // Sealed
                if !lockedCapsules.isEmpty {
                    sectionHeader(title: "Sealed", icon: "lock.fill", color: AppTheme.sealedTint)

                    ForEach(lockedCapsules) { capsule in
                        NavigationLink(destination: CapsuleDetailView(capsule: capsule)) {
                            CapsuleRow(capsule: capsule, isLocked: true, now: now, colorScheme: colorScheme)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteCapsule(capsule)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                // Bottom spacer for floating CTA
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: capsules.map(\.id))
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(AppTheme.Typography.overline)
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(AppTheme.secondaryLabel)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
        .padding(.bottom, AppTheme.Spacing.sm)
        .padding(.top, AppTheme.Spacing.md)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.xxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "clock.badge.plus")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(AppTheme.accent)
                    .symbolEffect(.pulse.wholeSymbol, options: .repeating, isActive: !reduceMotion)
            }
            .accessibilityHidden(true)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("No Memories Yet")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.label)

                Text("Seal a memory for your future self.\nIt'll be waiting when the time is right.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showingCreationSheet = true
            } label: {
                Label("Create First Memory", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.xxxl)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.accent, in: SwiftUI.Capsule())
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 10, y: 4)
            }
            .accessibilityLabel("Create your first memory capsule")

            Spacer()
        }
        .padding()
    }

    // MARK: - Computed Lists

    var lockedCapsules: [Capsule] {
        capsules
            .filter { !$0.isOpened && $0.unlockDate > now }
            .sorted { $0.unlockDate < $1.unlockDate }
    }

    var unlockedCapsules: [Capsule] {
        capsules
            .filter { $0.isOpened || $0.unlockDate <= now }
            .sorted { $0.unlockDate > $1.unlockDate }
    }

    // MARK: - Actions

    private func deleteCapsule(_ capsule: Capsule) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        storageManager.cancelNotification(for: capsule)
        storageManager.deleteMedia(for: capsule)
        modelContext.delete(capsule)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Capsule Row

struct CapsuleRow: View {
    let capsule: Capsule
    let isLocked: Bool
    let now: Date
    let colorScheme: ColorScheme

    private var accentEdge: Color {
        if !isLocked { return AppTheme.readyTint }
        if capsule.isSurprise { return AppTheme.surpriseTint }
        return AppTheme.sealedTint
    }

    private var iconName: String {
        if !isLocked { return "lock.open.fill" }
        if capsule.isSurprise { return "dice.fill" }
        return "lock.fill"
    }

    private var subtitleText: String {
        if !isLocked { return "Ready to open" }
        if capsule.isSurprise { return "Unlocks at a surprise date" }
        return capsule.unlockDate.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Color accent edge
            RoundedRectangle(cornerRadius: 2)
                .fill(accentEdge)
                .frame(width: 3)
                .padding(.vertical, AppTheme.Spacing.sm)

            HStack(spacing: AppTheme.Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentEdge.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentEdge)
                }
                .accessibilityHidden(true)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(capsule.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.label)
                        .lineLimit(1)

                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(isLocked ? AppTheme.secondaryLabel : AppTheme.readyTint)
                        .fontWeight(isLocked ? .regular : .medium)
                }

                Spacer(minLength: 0)

                // Countdown badge for locked capsules
                if isLocked && !capsule.isSurprise {
                    let remaining = capsule.unlockDate.timeIntervalSince(now)
                    if remaining > 0 {
                        Text(compactCountdown(remaining))
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(AppTheme.sealedTint)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, AppTheme.Spacing.xs)
                            .background(AppTheme.sealedTint.opacity(0.1), in: SwiftUI.Capsule())
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.tertiaryLabel)
            }
            .padding(.leading, AppTheme.Spacing.md)
            .padding(.trailing, AppTheme.Spacing.lg)
        }
        .padding(.vertical, AppTheme.Spacing.md)
        .background {
            let elevation = AppTheme.Elevation.small(colorScheme: colorScheme)
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(
                    color: elevation.color,
                    radius: elevation.radius,
                    y: elevation.y
                )
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLocked
            ? "\(capsule.title), \(capsule.isSurprise ? "sealed until a surprise date" : "sealed until \(subtitleText)")"
            : "\(capsule.title), ready to open")
        .accessibilityHint("Double-tap to open")
    }

    private func compactCountdown(_ interval: TimeInterval) -> String {
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if days > 0 { return "\(days)d" }
        if hours > 0 { return "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        let seconds = max(0, Int(interval))
        return "\(seconds)s"
    }
}

// MARK: - Section Header (kept for potential reuse)

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color)
            .textCase(nil)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Image(systemName: "hourglass")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AppTheme.secondaryLabel)
            Text("No Memories Yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.label)
        }
    }
}
