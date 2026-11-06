import SwiftUI
import WidgetKit

struct TrophyEntry: TimelineEntry {
    let date: Date
    let snapshot: PSNSnapshot?
    let error: String?
}

struct TrophyProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrophyEntry {
        TrophyEntry(date: .now, snapshot: .sample, error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TrophyEntry) -> Void) {
        let snapshot = context.isPreview ? (SharedStore.snapshot ?? .sample) : SharedStore.snapshot
        completion(TrophyEntry(date: .now, snapshot: snapshot, error: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrophyEntry>) -> Void) {
        Task {
            let entry: TrophyEntry
            if SharedStore.isConnected {
                do {
                    var fresh = try await PSNClient().fetchSnapshot()
                    if fresh.avatarData == nil { fresh.avatarData = SharedStore.snapshot?.avatarData }
                    SharedStore.snapshot = fresh
                    entry = TrophyEntry(date: .now, snapshot: fresh, error: nil)
                } catch {
                    entry = TrophyEntry(date: .now, snapshot: SharedStore.snapshot,
                                        error: error.localizedDescription)
                }
            } else {
                entry = TrophyEntry(date: .now, snapshot: nil, error: nil)
            }
            let next = Date().addingTimeInterval(entry.error == nil ? 30 * 60 : 10 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct TrophyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TrophyEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemSmall: SmallTrophyView(snapshot: snapshot)
            case .systemLarge: LargeTrophyView(snapshot: snapshot)
            default: MediumTrophyView(snapshot: snapshot)
            }
        } else {
            DisconnectedView(message: entry.error ?? "Ouvre l'app Trophées PSN pour te connecter.")
        }
    }
}

@main
struct PSNTrophiesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PSNTrophiesWidget", provider: TrophyProvider()) { entry in
            TrophyWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Trophées PlayStation")
        .description("Ton niveau, tes trophées platine, or, argent, bronze et tes jeux récents.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
