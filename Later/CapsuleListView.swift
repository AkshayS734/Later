import SwiftUI
import SwiftData
import Combine

struct CapsuleListView: View {
    @EnvironmentObject var storageManager: StorageManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Capsule.unlockDate) private var capsules: [Capsule]

    @State private var showingCreationSheet = false
    @State private var showingSettingsSheet = false
    @State private var now = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(colors: [Color(white: 0.1), Color.black], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Time Capsules")
                                    .font(.system(.largeTitle, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Spacer()
                                Button(action: { showingSettingsSheet = true }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.gray)
                                }
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityLabel("Settings")
                                
                                Button(action: { showingCreationSheet = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(Color.cyan)
                                }
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityLabel("Create new capsule")
                            }
                            // Stats line
                            if !capsules.isEmpty {
                                HStack(spacing: 6) {
                                    if lockedCapsules.count > 0 {
                                        Label("\(lockedCapsules.count) sealed", systemImage: "lock.fill")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    if lockedCapsules.count > 0 && unlockedCapsules.count > 0 {
                                        Text("·")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    if unlockedCapsules.count > 0 {
                                        Label("\(unlockedCapsules.count) ready", systemImage: "lock.open.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        if !unlockedCapsules.isEmpty {
                            SectionHeader(title: "Ready to Open", icon: "lock.open.fill", color: .green)
                            
                            ForEach(unlockedCapsules) { capsule in
                                NavigationLink(destination: CapsuleDetailView(capsule: capsule)) {
                                    CapsuleCard(capsule: capsule, isLocked: false, now: now)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        storageManager.cancelNotification(for: capsule)
                                        storageManager.deleteMedia(for: capsule)
                                        modelContext.delete(capsule)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        
                        if !lockedCapsules.isEmpty {
                            SectionHeader(title: "Sealed", icon: "lock.fill", color: .orange)
                            
                            ForEach(lockedCapsules) { capsule in
                                NavigationLink(destination: CapsuleDetailView(capsule: capsule)) {
                                    CapsuleCard(capsule: capsule, isLocked: true, now: now)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        storageManager.cancelNotification(for: capsule)
                                        storageManager.deleteMedia(for: capsule)
                                        modelContext.delete(capsule)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        
                        if capsules.isEmpty {
                            EmptyStateView()
                        }
                        
                        Color.clear.frame(height: 50)
                    }
                    .padding(.bottom, 20)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: unlockedCapsules.map(\.id))
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCreationSheet) {
                CapsuleCreationView()
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
            .onReceive(refreshTimer) { date in
                now = date
            }
            .onAppear {
                now = Date()
            }
        }
        // Respects user's appearance preference — no forced dark mode
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
}

// MARK: - Subviews

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

struct CapsuleCard: View {
    let capsule: Capsule
    let isLocked: Bool
    let now: Date
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Container
            ZStack {
                Circle()
                    .fill(isLocked ? Color.gray.opacity(0.2) : Color.green.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.title2)
                    .foregroundColor(isLocked ? .gray : .green)
            }
            
            // Text Content
            VStack(alignment: .leading, spacing: 4) {
                Text(capsule.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                
                if isLocked {
                    Text("Unlocks \(capsule.unlockDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                } else {
                    Text("Ready to view")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
                .accessibilityHidden(true)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.15))
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isLocked
                                ? LinearGradient(colors: [.cyan.opacity(0.4), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color(red: 1, green: 0.8, blue: 0.2).opacity(0.8), .orange.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLocked
            ? "\(capsule.title), sealed until \(capsule.unlockDate.formatted(date: .abbreviated, time: .shortened))"
            : "\(capsule.title), ready to view")
        .accessibilityHint("Double-tap to open")
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hourglass")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.top, 60)
                .accessibilityHidden(true)
            
            Text("No Memories Yet")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Text("Create a capsule to lock a memory for your future self.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}
