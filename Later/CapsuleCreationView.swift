import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import AVKit
import WidgetKit

// MARK: - File-based Transferable for media

struct MediaFile: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { received in
            let tempDir = FileManager.default.temporaryDirectory
            let destURL = tempDir
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: destURL)
            return MediaFile(url: destURL)
        }
    }
}

// MARK: - Quick Preset

enum SealPreset: String, CaseIterable {
    case oneDay   = "1 Day"
    case oneWeek  = "1 Week"
    case oneMonth = "1 Month"
    case oneYear  = "1 Year"
    case custom   = "Custom"
    
    var interval: TimeInterval? {
        switch self {
        case .oneDay:   return 86_400
        case .oneWeek:  return 7 * 86_400
        case .oneMonth: return 30 * 86_400
        case .oneYear:  return 365 * 86_400
        case .custom:   return nil
        }
    }
}

// MARK: - Creation View

struct CapsuleCreationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var storageManager: StorageManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var note: String = ""
    @State private var unlockDate: Date = Date().addingTimeInterval(86400)
    @State private var selectedPreset: SealPreset = .oneDay
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedMediaFileURL: URL?
    @State private var selectedMediaType: UTType?
    @State private var thumbnailImage: UIImage?
    @State private var isLoadingMedia = false
    
    private var canSave: Bool { !title.isEmpty && !isLoadingMedia }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark gradient background — consistent with list
                LinearGradient(
                    colors: [Color(white: 0.1), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        Text("New Memory")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        // Section 1: Memory Details
                        VStack(spacing: 12) {
                            TextField("Give it a title...", text: $title)
                                .font(.headline)
                                .foregroundColor(.white)
                                .tint(.cyan)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.cyan.opacity(title.isEmpty ? 0.2 : 0.6), lineWidth: 1)
                                )
                                .accessibilityLabel("Capsule title")
                                .accessibilityHint("Required. Give your memory a name.")
                            
                            TextField("Write a note to your future self...", text: $note, axis: .vertical)
                                .lineLimit(4...8)
                                .font(.body)
                                .foregroundColor(.white)
                                .tint(.cyan)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .accessibilityLabel("Memory note")
                                .accessibilityHint("Optional. Write a message to your future self.")
                        }
                        .colorScheme(.dark)   // fields always have dark bg — keep placeholder light
                        .padding(.horizontal)
                        
                        // Section 2: When to Unlock
                        VStack(alignment: .leading, spacing: 14) {
                            Text("When should this unlock?")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal)
                            
                            // Quick preset chips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(SealPreset.allCases, id: \.self) { preset in
                                        Button {
                                            withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
                                                selectedPreset = preset
                                                if let interval = preset.interval {
                                                    unlockDate = Date().addingTimeInterval(interval)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                if selectedPreset == preset {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption2.bold())
                                                }
                                                Text(preset.rawValue)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                            }
                                            .foregroundColor(selectedPreset == preset ? .black : .white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(
                                                selectedPreset == preset
                                                    ? Color.cyan
                                                    : Color.white.opacity(0.12)
                                            )
                                            .cornerRadius(20)
                                        }
                                        .frame(minHeight: 44)
                                        .accessibilityAddTraits(selectedPreset == preset ? .isSelected : [])
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Date picker shown only for Custom
                            if selectedPreset == .custom {
                                DatePicker(
                                    "Unlock Date",
                                    selection: $unlockDate,
                                    in: Date().addingTimeInterval(60)...
                                )
                                .datePickerStyle(.graphical)
                                .tint(.cyan)
                                .colorScheme(.dark)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                            }
                        }
                        
                        // Section 3: Media
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Attach a Memory")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal)
                            
                            PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                                mediaPickerLabel
                            }
                            .accessibilityLabel(thumbnailImage != nil ? "Change attached photo or video" : "Attach a photo or video. Optional.")
                            .padding(.horizontal)
                        }
                        
                        // Bottom "Seal Capsule" button
                        Button(action: saveCapsule) {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.fill")
                                Text("Seal Capsule")
                                    .fontWeight(.bold)
                            }
                            .font(.headline)
                            .foregroundColor(canSave ? .black : Color.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                canSave
                                    ? LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                            .shadow(color: canSave ? .cyan.opacity(0.4) : .clear, radius: 12, y: 6)
                        }
                        .disabled(!canSave)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: canSave)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanUpTempFile()
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
            .onChange(of: selectedItem) { newItem in
                loadMedia(newItem)
            }
        }
        // Respects user's appearance preference — no forced dark mode
    }
    
    // MARK: - Media picker label
    
    @ViewBuilder
    private var mediaPickerLabel: some View {
        if isLoadingMedia {
            HStack {
                ProgressView().tint(.cyan)
                Text("Processing...").foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
        } else if let thumbnail = thumbnailImage {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                
                // Change badge
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                    Text("Change")
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(10)
            }
        } else if selectedMediaFileURL != nil {
            // Video (no thumbnail generated yet) or fallback
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("Media Attached")
                        .font(.headline)
                        .foregroundColor(.white)
                    if let type = selectedMediaType {
                        Text(type.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(height: 200)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.largeTitle)
                    .foregroundColor(.cyan)
                    .accessibilityHidden(true)
                Text("Tap to add a Photo or Video")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                Text("Optional")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.cyan.opacity(0.3), style: Style.dash)
            )
        }
    }
    
    // MARK: - Logic
    
    private func loadMedia(_ newItem: PhotosPickerItem?) {
        Task {
            isLoadingMedia = true
            defer { isLoadingMedia = false }
            
            if let previousURL = selectedMediaFileURL {
                try? FileManager.default.removeItem(at: previousURL)
                selectedMediaFileURL = nil
                thumbnailImage = nil
            }
            
            guard let newItem else {
                selectedMediaType = nil
                return
            }
            
            if let type = newItem.supportedContentTypes.first {
                selectedMediaType = type
            } else {
                selectedMediaType = .jpeg
            }
            
            if let mediaFile = try? await newItem.loadTransferable(type: MediaFile.self) {
                selectedMediaFileURL = mediaFile.url
                
                // Generate thumbnail on background thread
                let fileURL = mediaFile.url
                let isMovie = selectedMediaType?.conforms(to: .movie) == true
                let thumb = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                    if isMovie {
                        let asset = AVURLAsset(url: fileURL)
                        let gen = AVAssetImageGenerator(asset: asset)
                        gen.appliesPreferredTrackTransform = true
                        if let cgImage = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                            return UIImage(cgImage: cgImage)
                        }
                    } else {
                        if let data = try? Data(contentsOf: fileURL) {
                            return UIImage(data: data)
                        }
                    }
                    return nil
                }.value
                thumbnailImage = thumb
            }
        }
    }
    
    private func saveCapsule() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let newCapsule = Capsule(
            title: title,
            note: note,
            mediaType: selectedMediaType?.identifier,
            unlockDate: unlockDate
        )
        
        if let sourceURL = selectedMediaFileURL {
            let path = storageManager.copyMedia(from: sourceURL, mediaType: selectedMediaType?.identifier, capsuleId: newCapsule.id)
            newCapsule.mediaPath = path
        }
        
        modelContext.insert(newCapsule)
        try? modelContext.save()
        
        storageManager.scheduleNotification(for: newCapsule)
        storageManager.requestNotificationPermissionIfNeeded()
        
        WidgetCenter.shared.reloadAllTimelines()
        
        dismiss()
    }
    
    private func cleanUpTempFile() {
        if let url = selectedMediaFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Styles

struct Style {
    static let dash = StrokeStyle(lineWidth: 2, lineCap: .round, dash: [10, 5])
}
