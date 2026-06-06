import SwiftUI
import SwiftData
import AVKit
import UniformTypeIdentifiers

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
    @ScaledMetric(relativeTo: .largeTitle) private var lockIconSize: CGFloat = 72
    @Environment(\.modelContext) private var modelContext

    // MARK: - Derived Colors

    /// On-surface tint that works on the deep navy locked background.
    private var lockedAccent: Color { Color.cyan.opacity(0.85) }
    /// Warm amber tint that harmonizes with the parchment unlocked background.
    private var unlockedAccent: Color { Color(red: 0.65, green: 0.32, blue: 0.0) }

    var body: some View {
        ZStack {
            // Intentional full-screen custom backgrounds — each state has its own emotional context.
            backgroundLayer

            // Burst celebration overlay
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
                .padding(.bottom, AppTheme.Spacing.xxxl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            capsule.isOpened
                ? AnyShapeStyle(Color(red: 1.0, green: 0.96, blue: 0.84))
                : AnyShapeStyle(Color(red: 0.07, green: 0.09, blue: 0.18)),
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(capsule.title)
                    .font(.headline)
                    .foregroundStyle(capsule.isOpened ? Color(red: 0.15, green: 0.1, blue: 0.05) : .white)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .foregroundStyle(capsule.isOpened ? unlockedAccent : .white.opacity(0.7))
                .accessibilityLabel("Delete capsule")
            }
        }
        .confirmationDialog(
            "Break the Seal?",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Open Capsule", role: .destructive) {
                performUnlock()
            }
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
        if capsule.isOpened {
            Rectangle()
                .fill(AppTheme.unlockedBackground)
                .ignoresSafeArea()
        } else {
            Rectangle()
                .fill(AppTheme.lockedBackground)
                .ignoresSafeArea()
        }
    }

    // MARK: - Burst Celebration

    private let burstColors: [Color] = [
        .yellow, .orange, Color(AppTheme.accent), .pink, .mint,
        .yellow, .orange, Color(AppTheme.accent), .pink, .mint,
        .yellow, .orange
    ]
    private let burstSizes: [CGFloat] = [10, 7, 13, 8, 11, 6, 14, 9, 12, 7, 10, 13]

    private var burstEffect: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) / 12.0 * 360.0
                Circle()
                    .fill(burstColors[i])
                    .frame(width: burstSizes[i], height: burstSizes[i])
                    .offset(
                        x: showUnlockAnimation ? cos(angle * .pi / 180) * 160 : 0,
                        y: showUnlockAnimation ? sin(angle * .pi / 180) * 160 : 0
                    )
                    .opacity(burstOpacity)
                    .animation(.easeOut(duration: 0.8).delay(Double(i) * 0.03), value: showUnlockAnimation)
            }
        }
        .scaleEffect(burstScale)
        .opacity(burstOpacity)
        .accessibilityHidden(true)
    }

    // MARK: - Locked State

    private func lockedContent(at now: Date) -> some View {
        VStack(spacing: AppTheme.Spacing.xxxl) {

            // Hero ring
            progressRing(at: now)
                .padding(.top, AppTheme.Spacing.xl)

            // Sealed-until label + date
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Sealed Until")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.45))

                if capsule.isSurprise {
                    Text("A Surprise Date")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                } else {
                    Text(capsule.unlockDate.formatted(date: .long, time: .shortened))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
            }

            // Countdown or unlock CTA
            if capsule.isUnlockable {
                Button {
                    showConfirmation = true
                } label: {
                    Label("Break Seal", systemImage: "lock.open.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.lg)
                        .background(.white)
                        .foregroundStyle(Color(red: 0.07, green: 0.09, blue: 0.18))
                        .clipShape(.rect(cornerRadius: AppTheme.Radius.lg))
                        .shadow(color: .white.opacity(0.2), radius: 12, y: 4)
                }
            } else {
                countdownRow(at: now)
            }

            // Metadata card — creation date & note preview
            lockedMetadataCard
        }
    }

    private func countdownRow(at now: Date) -> some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text("Time Remaining")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.45))

            if capsule.isSurprise {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.4))
                    Text("When the time is right…")
                        .font(.subheadline.italic())
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                Text(warmCountdown(to: capsule.unlockDate, from: now))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(lockedAccent)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.5), value: warmCountdown(to: capsule.unlockDate, from: now))
                    .accessibilityLabel("Time remaining: \(warmCountdown(to: capsule.unlockDate, from: now))")
            }
        }
    }

    private var lockedMetadataCard: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Divider
            HStack(spacing: AppTheme.Spacing.sm) {
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(height: 0.5)
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(height: 0.5)
            }
            .padding(.horizontal, AppTheme.Spacing.xl)

            HStack(spacing: AppTheme.Spacing.xxl) {
                metadataItem(
                    icon: "calendar.badge.plus",
                    label: "Sealed",
                    value: capsule.creationDate.formatted(date: .abbreviated, time: .omitted)
                )

                if !capsule.isSurprise {
                    metadataItem(
                        icon: "calendar.badge.clock",
                        label: "Opens",
                        value: capsule.unlockDate.formatted(date: .abbreviated, time: .omitted)
                    )
                }

                if capsule.mediaType != nil {
                    metadataItem(
                        icon: capsule.mediaType?.contains("video") == true ? "video.fill" : "photo.fill",
                        label: "Has",
                        value: capsule.mediaType?.contains("video") == true ? "Video" : "Photo"
                    )
                }
            }

            if !capsule.note.isEmpty {
                Text("Contains a note for your future self.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.top, AppTheme.Spacing.md)
    }

    private func metadataItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
                .accessibilityHidden(true)
            Text(label)
                .font(.caption2.weight(.medium))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.3))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    // MARK: - Progress Ring

    private func progressRing(at now: Date) -> some View {
        ZStack {
            // Track ring
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 4)
                .frame(width: 196, height: 196)

            // Progress ring
            Circle()
                .trim(from: 0, to: progressToUnlock(at: now))
                .stroke(
                    LinearGradient(
                        colors: [lockedAccent.opacity(0.5), lockedAccent],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 196, height: 196)
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: now)

            // Glow behind icon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [lockedAccent.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)

            // Lock / Dice icon
            Image(systemName: capsule.isSurprise ? "dice.fill" : "lock.fill")
                .font(.system(size: lockIconSize, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: lockedAccent.opacity(0.3), radius: 12)
                .scaleEffect(pulsing ? 1.04 : 1.0)
                .opacity(pulsing ? 0.9 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                    value: pulsing
                )
                .onAppear { pulsing = true }
                .accessibilityHidden(true)

            // Progress percentage pill — bottom of ring
            if !capsule.isSurprise {
                let pct = Int(progressToUnlock(at: now) * 100)
                Text("\(pct)%")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(lockedAccent.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.07), in: SwiftUI.Capsule())
                    .offset(y: 110)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Seal progress")
        .accessibilityValue("\(Int(progressToUnlock(at: now) * 100))% of the wait has passed")
    }

    // MARK: - Unlocked State

    private var unlockedContent: some View {
        VStack(spacing: AppTheme.Spacing.xxxl) {

            // Hero unlock header
            unlockHeader

            // Media
            if let mediaURL = storageManager.fullMediaURL(for: capsule) {
                mediaShowcase(for: mediaURL)
            }

            // Note card
            if !capsule.note.isEmpty {
                noteCard
            }

            // Memory metadata footer
            unlockedMetadataCard

            // Closing flourish
            closingFlourish
        }
    }

    private var unlockHeader: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(unlockedAccent.opacity(0.1))
                    .frame(width: 88, height: 88)
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(unlockedAccent)
            }
            .accessibilityHidden(true)

            VStack(spacing: AppTheme.Spacing.xs) {
                Text("Memory Unlocked")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color(red: 0.15, green: 0.1, blue: 0.05))

                Text("A message from your past self.")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.35, green: 0.25, blue: 0.10))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, AppTheme.Spacing.md)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            // Opening quote
            Image(systemName: "quote.opening")
                .font(.title)
                .foregroundStyle(unlockedAccent.opacity(0.6))
                .accessibilityHidden(true)

            // Note text
            Text(capsule.note)
                .font(.system(.body, design: .serif).italic())
                .lineSpacing(8)
                .foregroundStyle(Color(red: 0.15, green: 0.1, blue: 0.05))
                .multilineTextAlignment(.leading)

            // Closing quote
            HStack {
                Spacer()
                Image(systemName: "quote.closing")
                    .font(.title)
                    .foregroundStyle(unlockedAccent.opacity(0.6))
                    .accessibilityHidden(true)
            }
        }
        .padding(AppTheme.Spacing.xxl)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous)
                .fill(.white.opacity(0.75))
                .shadow(color: Color(red: 0.6, green: 0.35, blue: 0.0).opacity(0.12), radius: 20, x: 0, y: 8)
            RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous)
                .strokeBorder(unlockedAccent.opacity(0.15), lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
    }

    private var unlockedMetadataCard: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Rectangle()
                    .fill(unlockedAccent.opacity(0.2))
                    .frame(height: 0.75)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(unlockedAccent.opacity(0.5))
                Rectangle()
                    .fill(unlockedAccent.opacity(0.2))
                    .frame(height: 0.75)
            }
            .padding(.horizontal, AppTheme.Spacing.xl)

            HStack(spacing: AppTheme.Spacing.xxl) {
                unlockedMetaItem(
                    icon: "calendar.badge.plus",
                    label: "Sealed",
                    value: capsule.creationDate.formatted(date: .abbreviated, time: .omitted)
                )
                unlockedMetaItem(
                    icon: "calendar.badge.checkmark",
                    label: "Opened",
                    value: Date().formatted(date: .abbreviated, time: .omitted)
                )
                let days = Calendar.current.dateComponents([.day], from: capsule.creationDate, to: Date()).day ?? 0
                unlockedMetaItem(
                    icon: "hourglass",
                    label: "Waited",
                    value: days == 1 ? "1 day" : "\(days) days"
                )
            }
        }
        .padding(.vertical, AppTheme.Spacing.lg)
        .padding(.horizontal, AppTheme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                        .strokeBorder(unlockedAccent.opacity(0.12), lineWidth: 0.75)
                )
        }
    }

    private func unlockedMetaItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(unlockedAccent.opacity(0.55))
                .accessibilityHidden(true)
            Text(label)
                .font(.caption2.weight(.medium))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(unlockedAccent.opacity(0.5))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.05))
        }
    }

    private var closingFlourish: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(unlockedAccent.opacity(0.7))
                .accessibilityHidden(true)
            Text("Some memories are worth the wait.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color(red: 0.35, green: 0.25, blue: 0.10))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, AppTheme.Spacing.xl)
    }

    // MARK: - Media Showcase

    @ViewBuilder
    private func mediaShowcase(for url: URL) -> some View {
        Group {
            if let type = capsule.mediaType, UTType(type)?.conforms(to: .movie) == true {
                if let player {
                    VideoPlayer(player: player)
                        .frame(height: 340)
                        .clipShape(.rect(cornerRadius: AppTheme.Radius.xl, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous)
                            .fill(.white.opacity(0.55))
                        ProgressView()
                    }
                    .frame(height: 340)
                }
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous)
                                .fill(.white.opacity(0.55))
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 380)
                            .clipShape(.rect(cornerRadius: AppTheme.Radius.xl, style: .continuous))
                            .accessibilityLabel("Attached memory photo")
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous)
                                .fill(.white.opacity(0.55))
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: 380)
            }
        }
        .shadow(color: unlockedAccent.opacity(0.18), radius: 24, x: 0, y: 10)
    }

    // MARK: - Helpers

    private func progressToUnlock(at now: Date) -> CGFloat {
        let elapsed = now.timeIntervalSince(capsule.creationDate)
        let total = capsule.unlockDate.timeIntervalSince(capsule.creationDate)
        guard total > 0 else { return 1.0 }
        return min(max(CGFloat(elapsed / total), 0.0), 1.0)
    }

    private func warmCountdown(to date: Date, from now: Date) -> String {
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return "now" }

        let days    = Int(interval) / 86400
        let hours   = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days) days"
        } else if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours) hours"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    private func performUnlock() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        if reduceMotion {
            capsule.isOpened = true
            storageManager.cancelNotification(for: capsule)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            capsule.isOpened = true
            storageManager.cancelNotification(for: capsule)
        }
        showUnlockAnimation = true
        withAnimation(.easeOut(duration: 0.6)) {
            burstScale = 1.2
            burstOpacity = 1.0
        }
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
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
