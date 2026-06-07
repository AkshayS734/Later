import SwiftUI
import SwiftData
import AVKit
import UniformTypeIdentifiers
import WidgetKit

struct CapsuleDetailView: View {
    @EnvironmentObject var storageManager: StorageManager
    @Environment(\.dismiss) var dismiss
    let capsule: Capsule

    @State private var player: AVPlayer?
    @State private var showUnlockAnimation = false
    @State private var showConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var pulsing = false
    @State private var burstOpacity: Double = 0
    @State private var burstScale: CGFloat = 0.5
    @State private var hasAutoOpened = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var lockIconSize: CGFloat = 64
    @Environment(\.modelContext) private var modelContext

    // MARK: - Palette

    /// Accent for locked state — cool cyan on deep navy.
    private let lockedAccent = Color(red: 0.4, green: 0.7, blue: 1.0)
    /// Warm gold accent for the unlocked parchment state.
    private let unlockedAccent = Color(red: 0.6, green: 0.42, blue: 0.15)

    var body: some View {
        ZStack {
            backgroundLayer

            // Burst celebration
            if showUnlockAnimation && !reduceMotion {
                burstEffect
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            ScrollView {
                VStack(spacing: 0) {
                    if capsule.isOpened {
                        unlockedContent
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            lockedContent(at: timeline.date)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.xxl)
                .padding(.bottom, AppTheme.Spacing.xxxxl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            capsule.isOpened
                ? AnyShapeStyle(Color(red: 0.99, green: 0.97, blue: 0.93))
                : AnyShapeStyle(Color(red: 0.06, green: 0.06, blue: 0.16)),
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(capsule.title)
                    .font(.headline)
                    .foregroundStyle(capsule.isOpened ? Color(red: 0.15, green: 0.12, blue: 0.08) : .white)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                }
                .foregroundStyle(capsule.isOpened ? unlockedAccent.opacity(0.8) : .white.opacity(0.5))
                .accessibilityLabel("Delete capsule")
            }
        }
        .confirmationDialog(
            "Break the Seal?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Open Capsule", role: .destructive) { performUnlock() }
            Button("Not Yet", role: .cancel) { }
        } message: {
            Text("Once opened, this memory can't be re-sealed.")
        }
        .confirmationDialog(
            "Delete this Capsule?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                storageManager.deleteMedia(for: capsule)
                modelContext.delete(capsule)
                try? modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This memory and its contents will be permanently removed.")
        }
        .onAppear {
            if capsule.isOpened {
                setupPlayer()
            } else if capsule.isUnlockable && !hasAutoOpened {
                hasAutoOpened = true
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    performUnlock()
                }
            }
        }
        .onChange(of: capsule.isOpened) {
            if capsule.isOpened { setupPlayer() }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            if capsule.isOpened {
                Rectangle().fill(AppTheme.unlockedBackground).ignoresSafeArea()
            } else {
                Rectangle().fill(AppTheme.lockedBackground).ignoresSafeArea()
                // Subtle radial moonlight glow
                RadialGradient(
                    colors: [lockedAccent.opacity(0.04), .clear],
                    center: .init(x: 0.5, y: 0.2),
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Burst Celebration

    private let burstColors: [Color] = [
        .white, Color(.systemIndigo), .cyan, .purple, .mint,
        .white, Color(.systemIndigo), .cyan, .purple, .mint,
        .white, Color(.systemIndigo), .cyan, .purple, .mint,
        .white, .cyan, .purple
    ]

    private let burstSizes: [CGFloat] = [
        10, 7, 13, 8, 11, 6, 14, 9, 12, 7, 10, 13, 8, 11, 6, 14, 9, 12
    ]

    private var burstEffect: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { i in
                let angle = Double(i) / 18.0 * 360.0
                let size = burstSizes[i]
                Circle()
                    .fill(burstColors[i])
                    .frame(width: size, height: size)
                    .offset(
                        x: showUnlockAnimation ? cos(angle * .pi / 180) * 180 : 0,
                        y: showUnlockAnimation ? sin(angle * .pi / 180) * 180 : 0
                    )
                    .opacity(burstOpacity)
                    .animation(.easeOut(duration: 0.9).delay(Double(i) * 0.02), value: showUnlockAnimation)
            }
        }
        .scaleEffect(burstScale)
        .opacity(burstOpacity)
        .accessibilityHidden(true)
    }

    // MARK: - Locked Content

    private func lockedContent(at now: Date) -> some View {
        VStack(spacing: AppTheme.Spacing.xxxl) {

            // Hero progress ring
            progressRing(at: now)
                .padding(.top, AppTheme.Spacing.xl)

            // Sealed-until
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("SEALED UNTIL")
                    .font(AppTheme.Typography.overline)
                    .tracking(2.0)
                    .foregroundStyle(.white.opacity(0.35))

                if capsule.isSurprise {
                    Text("A Surprise Date")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Text(capsule.unlockDate.formatted(date: .long, time: .shortened))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
            }

            // CTA or Countdown
            if capsule.isUnlockable {
                unlockButton
            } else {
                countdownSection(at: now)
            }

            // Metadata
            lockedMetadata
        }
    }

    // MARK: - Segmented Countdown

    private func countdownSection(at now: Date) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("TIME REMAINING")
                .font(AppTheme.Typography.overline)
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.3))

            if capsule.isSurprise {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "questionmark.circle")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.35))
                    Text("When the time is right…")
                        .font(.subheadline.italic())
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else {
                let interval = capsule.unlockDate.timeIntervalSince(now)
                let totalSeconds = max(Int(interval), 0)
                let d = totalSeconds / 86400
                let h = (totalSeconds % 86400) / 3600
                let m = (totalSeconds % 3600) / 60
                let s = totalSeconds % 60

                HStack(spacing: AppTheme.Spacing.sm) {
                    if d > 0 { countdownUnit(value: d, label: "DAYS") }
                    countdownUnit(value: h, label: "HRS")
                    countdownUnit(value: m, label: "MIN")
                    countdownUnit(value: s, label: "SEC")
                }
                .animation(.easeInOut(duration: 0.3), value: totalSeconds)
            }
        }
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(minWidth: 52)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Unlock Button

    private var unlockButton: some View {
         Button {
             UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
             showConfirmation = true
         } label: {
             Label("Break Seal", systemImage: "lock.open.fill")
                 .font(.headline)
                 .frame(maxWidth: .infinity)
                 .padding(.vertical, AppTheme.Spacing.lg)
                 .foregroundStyle(Color(red: 0.06, green: 0.06, blue: 0.16))
                 .background(.white, in: RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
                 .shadow(color: .white.opacity(0.15), radius: 16, y: 4)
         }
     }

    // MARK: - Locked Metadata

    private var lockedMetadata: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Divider
            HStack(spacing: AppTheme.Spacing.sm) {
                Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5)
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.2))
                Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5)
            }

            HStack(spacing: 0) {
                lockedMetaItem(icon: "calendar.badge.plus", label: "Sealed", value: capsule.creationDate.formatted(date: .abbreviated, time: .omitted))

                if !capsule.isSurprise {
                    lockedMetaItem(icon: "calendar.badge.clock", label: "Opens", value: capsule.unlockDate.formatted(date: .abbreviated, time: .omitted))
                }

                if capsule.mediaType != nil {
                    lockedMetaItem(
                        icon: capsule.mediaType?.contains("video") == true ? "video.fill" : "photo.fill",
                        label: "Media",
                        value: capsule.mediaType?.contains("video") == true ? "Video" : "Photo"
                    )
                }
            }

            if !capsule.note.isEmpty {
                Text("Contains a note for your future self.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .padding(.top, AppTheme.Spacing.sm)
    }

    private func lockedMetaItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.25))
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.2))
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress Ring

    private func progressRing(at now: Date) -> some View {
        ZStack {
            // Track
            Circle()
                .stroke(.white.opacity(0.06), lineWidth: 6)
                .frame(width: 220, height: 220)

            // Progress fill
            Circle()
                .trim(from: 0, to: progressToUnlock(at: now))
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.accent, lockedAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .shadow(color: lockedAccent.opacity(0.35), radius: 8)
                .animation(reduceMotion ? nil : .linear(duration: 1), value: now)

            // Inner glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.accent.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .accessibilityHidden(true)

            // Center icon
            Image(systemName: capsule.isSurprise ? "dice.fill" : "lock.fill")
                .font(.system(size: lockIconSize, weight: .light))
                .foregroundStyle(.white)
                .shadow(color: lockedAccent.opacity(0.25), radius: 16)
                .scaleEffect(pulsing ? 1.03 : 1.0)
                .opacity(pulsing ? 0.92 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                    value: pulsing
                )
                .onAppear { pulsing = true }
                .accessibilityHidden(true)

            // Percentage pill
            if !capsule.isSurprise {
                let pct = Int(progressToUnlock(at: now) * 100)
                Text("\(pct)%")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(lockedAccent.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.06), in: SwiftUI.Capsule())
                    .offset(y: 124)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Seal progress")
        .accessibilityValue("\(Int(progressToUnlock(at: now) * 100))% complete")
    }

    // MARK: - Unlocked Content

    private var unlockedContent: some View {
        VStack(spacing: AppTheme.Spacing.xxxl) {
            unlockHeader
            if let mediaURL = storageManager.fullMediaURL(for: capsule) {
                mediaShowcase(for: mediaURL)
            }
            if !capsule.note.isEmpty { noteCard }
            unlockedMetadata
        }
    }

    // MARK: - Unlock Header

    private var unlockHeader: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Text("Memory Unlocked")
                .font(AppTheme.Typography.heroTitle)
                .foregroundStyle(Color(red: 0.15, green: 0.12, blue: 0.08))

            // Date line
            HStack(spacing: AppTheme.Spacing.sm) {
                Text("Sealed \(capsule.creationDate.formatted(date: .abbreviated, time: .omitted))")
                Circle().fill(unlockedAccent.opacity(0.4)).frame(width: 3, height: 3)
                Text("Opened \(Date().formatted(date: .abbreviated, time: .omitted))")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(unlockedAccent.opacity(0.7))

            // Decorative line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, unlockedAccent.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, AppTheme.Spacing.xxxxl)
        }
        .padding(.top, AppTheme.Spacing.lg)
    }

    // MARK: - Note Card

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Text(capsule.note)
                .font(.system(.body, design: .serif))
                .lineSpacing(8)
                .foregroundStyle(Color(red: 0.15, green: 0.12, blue: 0.08))
                .multilineTextAlignment(.leading)
        }
        .padding(AppTheme.Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .shadow(color: unlockedAccent.opacity(0.1), radius: 20, x: 0, y: 8)
            RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous)
                .strokeBorder(unlockedAccent.opacity(0.12), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Unlocked Metadata

    private var unlockedMetadata: some View {
        HStack(spacing: 0) {
            let days = Calendar.current.dateComponents([.day], from: capsule.creationDate, to: Date()).day ?? 0

            unlockedMetaItem(icon: "calendar.badge.plus", label: "Sealed", value: capsule.creationDate.formatted(date: .abbreviated, time: .omitted))
            unlockedMetaItem(icon: "calendar.badge.checkmark", label: "Opened", value: Date().formatted(date: .abbreviated, time: .omitted))
            unlockedMetaItem(icon: "hourglass", label: "Waited", value: days == 1 ? "1 day" : "\(days) days")
        }
        .padding(.vertical, AppTheme.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(Color.white.opacity(0.5))
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .strokeBorder(unlockedAccent.opacity(0.1), lineWidth: 0.5)
        }
    }

    private func unlockedMetaItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(unlockedAccent.opacity(0.5))
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(unlockedAccent.opacity(0.4))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.1))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Media Showcase

    @ViewBuilder
    private func mediaShowcase(for url: URL) -> some View {
        Group {
            if let type = capsule.mediaType, UTType(type)?.conforms(to: .movie) == true {
                if let player {
                    VideoPlayer(player: player)
                        .frame(height: 340)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xxl, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.xxl, style: .continuous)
                            .fill(Color.white.opacity(0.5))
                        ProgressView()
                    }
                    .frame(height: 340)
                }
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.xxl, style: .continuous)
                                .fill(Color.white.opacity(0.5))
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xxl, style: .continuous))
                            .overlay(
                                // Inner shadow for depth
                                RoundedRectangle(cornerRadius: AppTheme.Radius.xxl, style: .continuous)
                                    .strokeBorder(.black.opacity(0.08), lineWidth: 1)
                            )
                            .accessibilityLabel("Attached memory photo")
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.xxl, style: .continuous)
                                .fill(Color.white.opacity(0.5))
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .shadow(color: unlockedAccent.opacity(0.15), radius: 24, x: 0, y: 12)
    }

    // MARK: - Helpers

    private func progressToUnlock(at now: Date) -> CGFloat {
        let elapsed = now.timeIntervalSince(capsule.creationDate)
        let total = capsule.unlockDate.timeIntervalSince(capsule.creationDate)
        guard total > 0 else { return 1.0 }
        return min(max(CGFloat(elapsed / total), 0.0), 1.0)
    }

    private func performUnlock() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        if reduceMotion {
            capsule.isOpened = true
            storageManager.cancelNotification(for: capsule)
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            capsule.isOpened = true
            storageManager.cancelNotification(for: capsule)
        }
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        showUnlockAnimation = true
        withAnimation(.easeOut(duration: 0.6)) {
            burstScale = 1.3
            burstOpacity = 1.0
        }
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeIn(duration: 0.5)) { burstOpacity = 0 }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await Task.sleep(nanoseconds: 600_000_000)
            showUnlockAnimation = false
            burstScale = 0.5
        }
    }

    private func setupPlayer() {
        guard player == nil,
              let mediaURL = storageManager.fullMediaURL(for: capsule),
              let type = capsule.mediaType,
              UTType(type)?.conforms(to: .movie) == true else { return }
        player = AVPlayer(url: mediaURL)
    }
}
