import SwiftUI
import SwiftData
import Combine

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
            Group {
                if capsules.isEmpty {
                    emptyState
                } else {
                    capsuleList
                }
            }
            .navigationTitle("Time Capsules")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Settings")
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showingCreationSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("New Memory")
                                .fontWeight(.semibold)
                        }
                    }
                    .accessibilityLabel("Create new memory capsule")
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

    // MARK: - Capsule List

    private var capsuleList: some View {
        List {
            if !unlockedCapsules.isEmpty {
                Section {
                    ForEach(unlockedCapsules) { capsule in
                        NavigationLink(destination: CapsuleDetailView(capsule: capsule)) {
                            CapsuleRow(capsule: capsule, isLocked: false, now: now)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete { offsets in
                        deleteCapsules(from: unlockedCapsules, at: offsets)
                    }
                } header: {
                    Label("Ready to Open", systemImage: "lock.open.fill")
                        .foregroundStyle(AppTheme.readyTint)
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }
            }

            if !lockedCapsules.isEmpty {
                Section {
                    ForEach(lockedCapsules) { capsule in
                        NavigationLink(destination: CapsuleDetailView(capsule: capsule)) {
                            CapsuleRow(capsule: capsule, isLocked: true, now: now)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete { offsets in
                        deleteCapsules(from: lockedCapsules, at: offsets)
                    }
                } header: {
                    Label("Sealed", systemImage: "lock.fill")
                        .foregroundStyle(AppTheme.sealedTint)
                        .font(.footnote.weight(.semibold))
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: lockedCapsules.map(\.id))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()
            Image(systemName: "clock.badge.plus")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(AppTheme.secondaryLabel)
                .accessibilityHidden(true)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("No Memories Yet")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.label)

                Text("Seal a memory for your future self.\nIt'll be waiting when the time is right.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button {
                showingCreationSheet = true
            } label: {
                Label("New Memory", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, AppTheme.Spacing.xxl)
                    .padding(.vertical, AppTheme.Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(.rect(cornerRadius: AppTheme.Radius.lg))
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

    private func deleteCapsules(from list: [Capsule], at offsets: IndexSet) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        for index in offsets {
            let capsule = list[index]
            storageManager.cancelNotification(for: capsule)
            storageManager.deleteMedia(for: capsule)
            modelContext.delete(capsule)
        }
    }
}

// MARK: - Capsule Row

struct CapsuleRow: View {
    let capsule: Capsule
    let isLocked: Bool
    let now: Date

    private var iconName: String {
        if !isLocked { return "lock.open.fill" }
        if capsule.isSurprise { return "dice.fill" }
        return "lock.fill"
    }

    private var iconColor: Color {
        if !isLocked { return AppTheme.readyTint }
        if capsule.isSurprise { return AppTheme.surpriseTint }
        return AppTheme.sealedTint
    }

    private var subtitleText: String {
        if !isLocked { return "Ready to open" }
        if capsule.isSurprise { return "Unlocks at a surprise date" }
        return capsule.unlockDate.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .accessibilityHidden(true)

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(capsule.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.label)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.footnote)
                    .foregroundStyle(isLocked ? AppTheme.secondaryLabel : AppTheme.readyTint)
                    .fontWeight(isLocked ? .regular : .medium)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLocked
            ? "\(capsule.title), \(capsule.isSurprise ? "sealed until a surprise date" : "sealed until \(subtitleText)")"
            : "\(capsule.title), ready to open")
        .accessibilityHint("Double-tap to open")
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
