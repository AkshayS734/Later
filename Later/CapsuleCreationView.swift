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

// MARK: - Unlock Preset

enum SealPreset: String, CaseIterable {
    case oneDay    = "1 Day"
    case oneWeek   = "1 Week"
    case oneMonth  = "1 Month"
    case oneYear   = "1 Year"
    case surpriseMe = "Surprise Me"
    case custom    = "Custom"

    var interval: TimeInterval? {
        switch self {
        case .oneDay:    return 86_400
        case .oneWeek:   return 7 * 86_400
        case .oneMonth:  return 30 * 86_400
        case .oneYear:   return 365 * 86_400
        case .surpriseMe: return Double.random(in: 2_592_000...94_608_000)
        case .custom:    return nil
        }
    }

    var icon: String {
        switch self {
        case .oneDay:    return "sun.rise"
        case .oneWeek:   return "calendar.badge.clock"
        case .oneMonth:  return "calendar"
        case .oneYear:   return "hourglass"
        case .surpriseMe: return "dice"
        case .custom:    return "slider.horizontal.3"
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

    @State private var currentPromptIndex = 0
    @State private var showingPrompt = false

    let prompts = [
        "What is your biggest dream right now?",
        "Write down 3 things you are grateful for today.",
        "What advice would you give yourself in 5 years?",
        "Where do you hope to be in a year?",
        "What is currently your favorite song and movie?",
        "Describe a challenge you recently overcame.",
        "What is a risk you want to take soon?"
    ]

    private var canSave: Bool { !title.isEmpty && !isLoadingMedia }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Memory Section
                Section {
                    TextField("Title", text: $title)
                        .font(.body)
                        .accessibilityLabel("Memory title")
                        .accessibilityHint("Required. Give your memory a name.")

                    ZStack(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("Write a note to your future self…")
                                .foregroundStyle(AppTheme.placeholderText)
                                .font(.body)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $note)
                            .font(.body)
                            .frame(minHeight: 100)
                            .accessibilityLabel("Memory note")
                            .accessibilityHint("Optional. Write a message to your future self.")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("Memory")
                }

                // MARK: Inspiration (Progressive Disclosure)
                Section {
                    DisclosureGroup(
                        isExpanded: $showingPrompt,
                        content: {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                                Text(prompts[currentPromptIndex])
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryLabel)
                                    .italic()
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, AppTheme.Spacing.sm)

                                HStack {
                                    Button("Use this prompt") {
                                        let insertion = prompts[currentPromptIndex] + "\n\n"
                                        note = note.isEmpty ? insertion : note + insertion
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .buttonStyle(.borderless)

                                    Spacer()

                                    Button {
                                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                            currentPromptIndex = (currentPromptIndex + 1) % prompts.count
                                        }
                                    } label: {
                                        Label("Next prompt", systemImage: "arrow.2.circlepath")
                                            .labelStyle(.iconOnly)
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(AppTheme.secondaryLabel)
                                    .accessibilityLabel("Shuffle prompt")
                                }
                            }
                        },
                        label: {
                            Label("Writing Prompts", systemImage: "lightbulb")
                                .foregroundStyle(AppTheme.secondaryLabel)
                                .font(.subheadline)
                        }
                    )
                }

                // MARK: Unlock Date Section
                Section {
                    // Preset chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(SealPreset.allCases, id: \.self) { preset in
                                presetChip(preset)
                            }
                        }
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .padding(.horizontal, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    // Custom date picker
                    if selectedPreset == .custom {
                        DatePicker(
                            "Unlock Date",
                            selection: $unlockDate,
                            in: Date().addingTimeInterval(60)...
                        )
                        .datePickerStyle(.compact)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    }

                    // Surprise capsule explanation
                    if selectedPreset == .surpriseMe {
                        Label("The unlock date is a secret — even from you.", systemImage: "questionmark.circle")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryLabel)
                            .listRowBackground(AppTheme.surpriseTint.opacity(0.08))
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
                    }
                } header: {
                    Text("When to Unlock")
                }

                // MARK: Media Section
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .videos])) {
                        mediaPickerLabel
                    }
                    .accessibilityLabel(thumbnailImage != nil ? "Change attached photo or video" : "Attach a photo or video. Optional.")
                } header: {
                    Text("Attachment")
                }
            }
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanUpTempFile()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Seal") {
                        saveCapsule()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                loadMedia(newItem)
            }
        }
    }

    // MARK: - Preset Chip

    @ViewBuilder
    private func presetChip(_ preset: SealPreset) -> some View {
        let isSelected = selectedPreset == preset
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3)) {
                selectedPreset = preset
                if let interval = preset.interval {
                    unlockDate = Date().addingTimeInterval(interval)
                }
            }
        } label: {
            Label(preset.rawValue, systemImage: preset.icon)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color(.systemBackground) : AppTheme.secondaryLabel)
                .labelStyle(.titleOnly)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(isSelected ? AppTheme.accent : Color(.tertiarySystemFill), in: SwiftUI.Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Media Picker Label

    @ViewBuilder
    private var mediaPickerLabel: some View {
        if isLoadingMedia {
            HStack(spacing: AppTheme.Spacing.sm) {
                ProgressView()
                Text("Processing…")
                    .foregroundStyle(AppTheme.secondaryLabel)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        } else if let thumbnail = thumbnailImage {
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
                    .clipShape(.rect(cornerRadius: AppTheme.Radius.md))

                Label("Change", systemImage: "pencil.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(.ultraThinMaterial, in: SwiftUI.Capsule())
                    .padding(AppTheme.Spacing.sm)
            }
        } else if selectedMediaFileURL != nil {
            Label("Media attached", systemImage: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.readyTint)
                .frame(maxWidth: .infinity, minHeight: 44)
        } else {
            Label("Add Photo or Video", systemImage: "photo.on.rectangle")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryLabel)
                .frame(maxWidth: .infinity, minHeight: 44)
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

                let fileURL = mediaFile.url
                let isMovie = selectedMediaType?.conforms(to: .movie) == true
                let thumb = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                    if isMovie {
                        let asset = AVURLAsset(url: fileURL)
                        let gen = AVAssetImageGenerator(asset: asset)
                        gen.appliesPreferredTrackTransform = true
                        gen.maximumSize = CGSize(width: 600, height: 600)
                        if let cgImage = try? await gen.image(at: .zero).image {
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
            unlockDate: unlockDate,
            isSurprise: selectedPreset == .surpriseMe
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

// MARK: - Styles (kept for backward compatibility)

struct Style {
    static let dash = StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [8, 4])
}
