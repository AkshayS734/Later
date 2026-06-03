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
    @ScaledMetric(relativeTo: .largeTitle) private var lockIconSize: CGFloat = 80
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            // Background
            if capsule.isOpened {
                Theme.unlockedBackground
                    .ignoresSafeArea()
            } else {
                Theme.lockedBackground
                    .ignoresSafeArea()
            }
            
            // Burst overlay for unlock celebration
            if showUnlockAnimation && !reduceMotion {
                burstEffect
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            ScrollView {
                VStack(spacing: 30) {
                    if capsule.isOpened {
                        unlockedContent
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale))
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            lockedContent(at: timeline.date)
                        }
                    }
                }
                .padding()
                .padding(.top, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            capsule.isOpened
                ? AnyShapeStyle(Color(red: 1.0, green: 0.92, blue: 0.75))
                : AnyShapeStyle(Color(red: 0.1, green: 0.1, blue: 0.2)),
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(capsule.title)
                    .font(.headline)
                    .foregroundColor(capsule.isOpened ? Color(red: 0.15, green: 0.1, blue: 0.05) : .white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(capsule.isOpened ? Color(red: 0.6, green: 0.2, blue: 0.0) : .red.opacity(0.8))
                }
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
        .onChange(of: capsule.isOpened) { isOpened in
            if isOpened {
                setupPlayer()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    // MARK: - Burst Celebration
    
    private let burstColors: [Color] = [.yellow, .orange, .cyan, .pink, .mint, .yellow, .orange, .cyan, .pink, .mint, .yellow, .orange]
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
    
    // MARK: - Locked Content
    
    private func lockedContent(at now: Date) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: progressToUnlock(at: now))
                    .stroke(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: now)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: lockIconSize))
                    .foregroundColor(.white)
                    .shadow(color: .cyan.opacity(0.5), radius: 20)
                    .scaleEffect(pulsing ? 1.06 : 1.0)
                    .opacity(pulsing ? 0.85 : 1.0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                        value: pulsing
                    )
                    .onAppear { pulsing = true }
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Time until unlock")
            .accessibilityValue("\(Int(progressToUnlock(at: now) * 100))% of the wait has passed")
            .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text("Sealed Until")
                    .font(.subheadline)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundColor(Color.white.opacity(0.7))
                
                Text(capsule.unlockDate.formatted(date: .long, time: .shortened))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            if capsule.isUnlockable {
                Button(action: { showConfirmation = true }) {
                    Label("Break Seal", systemImage: "lock.open.fill")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .white.opacity(0.3), radius: 10)
                }
                .padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    Text("Time Remaining")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                    
                    Text(warmCountdown(to: capsule.unlockDate, from: now))
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(.cyan)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.5), value: warmCountdown(to: capsule.unlockDate, from: now))
                        .accessibilityLabel("Time remaining: \(warmCountdown(to: capsule.unlockDate, from: now))")
                }
                .padding(.top, 20)
            }
        }
    }
    
    // MARK: - Unlocked Content
    
    private var unlockedContent: some View {
        VStack(spacing: 32) {
            if let mediaURL = storageManager.fullMediaURL(for: capsule) {
                mediaShowcase(for: mediaURL)
            }
            
            if !capsule.note.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "quote.opening")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.7, green: 0.35, blue: 0.0))
                            .accessibilityHidden(true)
                        Spacer()
                    }
                    
                    Text(capsule.note)
                        .font(.system(.title3, design: .serif))
                        .italic()
                        .lineSpacing(8)
                        .foregroundColor(Color(red: 0.15, green: 0.1, blue: 0.05))
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 8)
                    
                    HStack {
                        Spacer()
                        Image(systemName: "quote.closing")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.7, green: 0.35, blue: 0.0))
                            .accessibilityHidden(true)
                    }
                }
                .padding(24)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.85))
                        .shadow(color: .orange.opacity(0.15), radius: 20, x: 0, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white, lineWidth: 1)
                        )
                }
            }
            
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(Color(red: 0.7, green: 0.35, blue: 0.0))
                    .font(.title2)
                    .accessibilityHidden(true)
                Text("Some memories need time.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(red: 0.15, green: 0.1, blue: 0.05))
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
    
    @ViewBuilder
    private func mediaShowcase(for url: URL) -> some View {
        Group {
            if let type = capsule.mediaType, UTType(type)?.conforms(to: .movie) == true {
                if let player {
                    VideoPlayer(player: player)
                        .frame(height: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.7))
                        ProgressView()
                    }
                    .frame(height: 350)
                }
            } else {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.7))
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .accessibilityLabel("Attached memory photo")
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.7))
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle)
                                .foregroundColor(.gray.opacity(0.5))
                                .accessibilityHidden(true)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .shadow(color: .orange.opacity(0.2), radius: 25, x: 0, y: 15)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white, lineWidth: 1)
        )
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
        
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
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
            withAnimation(.easeIn(duration: 0.5)) {
                burstOpacity = 0
            }
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
