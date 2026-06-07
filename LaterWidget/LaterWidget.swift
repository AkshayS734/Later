import WidgetKit
import SwiftUI
import SwiftData

struct WidgetCapsule {
    let title: String
    let unlockDate: Date
    let isSurprise: Bool
}

@MainActor
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> CapsuleEntry {
        CapsuleEntry(date: Date(), nextCapsule: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CapsuleEntry) -> ()) {
        let entry = CapsuleEntry(date: Date(), nextCapsule: getNextCapsule())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let nextCapsule = getNextCapsule()
        let entry = CapsuleEntry(date: Date(), nextCapsule: nextCapsule)

        // Refresh every hour or when the next capsule unlocks
        var nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        if let unlockDate = nextCapsule?.unlockDate, unlockDate > Date(), unlockDate < nextUpdate {
            nextUpdate = unlockDate
        }

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func getNextCapsule() -> WidgetCapsule? {
        let schema = Schema([Capsule.self])
        let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.akshay.Later")!
        let storeURL = appGroupURL.appendingPathComponent("Capsules.sqlite")
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        guard let modelContainer = try? ModelContainer(for: schema, configurations: [modelConfiguration]) else {
            return nil
        }
        let now = Date()
        let descriptor = FetchDescriptor<Capsule>(
            predicate: #Predicate { !$0.isOpened && $0.unlockDate > now },
            sortBy: [SortDescriptor(\.unlockDate, order: .forward)]
        )
        guard let capsule = try? modelContainer.mainContext.fetch(descriptor).first else { return nil }

        return WidgetCapsule(title: capsule.title, unlockDate: capsule.unlockDate, isSurprise: capsule.isSurprise)
    }
}

struct CapsuleEntry: TimelineEntry {
    let date: Date
    let nextCapsule: WidgetCapsule?
}

struct LaterWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if let capsule = entry.nextCapsule {
                capsuleContent(capsule)
            } else {
                emptyContent
            }
        }
    }

    // MARK: - Capsule Content

    private func capsuleContent(_ capsule: WidgetCapsule) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header badge
            HStack(spacing: 6) {
                Image(systemName: capsule.isSurprise ? "dice.fill" : "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(.systemIndigo))

                Text("SEALED MEMORY")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.5))

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.white.opacity(0.06), in: SwiftUI.Capsule())
            .padding(.bottom, 12)

            // Title
            Text(capsule.title)
                .font(.system(size: family == .systemMedium ? 20 : 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer()

            // Countdown
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UNLOCKS IN")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(.white.opacity(0.4))

                    if capsule.isSurprise {
                        Text("???")
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(.systemIndigo), .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else {
                        Text(capsule.unlockDate, style: .timer)
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(.systemIndigo))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                if family == .systemMedium {
                    Spacer()
                    // Right-side icon for medium widget
                    ZStack {
                        Circle()
                            .fill(Color(.systemIndigo).opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: capsule.isSurprise ? "dice.fill" : "hourglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(.systemIndigo).opacity(0.7))
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyContent: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 52, height: 52)
                Image(systemName: "clock.badge.plus")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white.opacity(0.3))
            }

            Text("No sealed capsules")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
    }
}

struct LaterWidget: Widget {
    let kind: String = "LaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                LaterWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [
                                Color(red: 0.06, green: 0.06, blue: 0.16),
                                Color(red: 0.02, green: 0.02, blue: 0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.06, blue: 0.16),
                            Color(red: 0.02, green: 0.02, blue: 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    LaterWidgetEntryView(entry: entry)
                        .padding()
                }
            }
        }
        .configurationDisplayName("Upcoming Capsule")
        .description("Keep track of your next memory unlocking.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
