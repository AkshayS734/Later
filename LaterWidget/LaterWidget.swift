import WidgetKit
import SwiftUI
import SwiftData

struct WidgetCapsule {
    let title: String
    let unlockDate: Date
    let isSurprise: Bool
}

struct Provider: TimelineProvider {
    @MainActor
    func placeholder(in context: Context) -> CapsuleEntry {
        CapsuleEntry(date: Date(), nextCapsule: nil)
    }

    @MainActor
    func getSnapshot(in context: Context, completion: @escaping (CapsuleEntry) -> ()) {
        let entry = CapsuleEntry(date: Date(), nextCapsule: getNextCapsule())
        completion(entry)
    }

    @MainActor
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
    
    @MainActor
    private func getNextCapsule() -> WidgetCapsule? {
        // Provide the schema to ModelContainer
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

struct LaterWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Group {
            if let capsule = entry.nextCapsule {
                // We have a capsule
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.orange)
                            .shadow(color: .orange.opacity(0.5), radius: 3, x: 0, y: 0)
                        
                        Text("SEALED MEMORY")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                    }
                    .padding(.bottom, 12)
                    
                    Text(capsule.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("UNLOCKS IN")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                            
                            if capsule.isSurprise {
                                Text("???")
                                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.cyan)
                            } else {
                                Text(capsule.unlockDate, style: .timer)
                                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("No sealed capsules")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
            }
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
                        if entry.nextCapsule != nil {
                            LinearGradient(colors: [Color(red: 0.05, green: 0.1, blue: 0.15), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                        } else {
                            LinearGradient(colors: [Color(white: 0.15), Color(white: 0.05)], startPoint: .top, endPoint: .bottom)
                        }
                    }
            } else {
                ZStack {
                    if entry.nextCapsule != nil {
                        LinearGradient(colors: [Color(red: 0.05, green: 0.1, blue: 0.15), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    } else {
                        LinearGradient(colors: [Color(white: 0.15), Color(white: 0.05)], startPoint: .top, endPoint: .bottom)
                    }
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
