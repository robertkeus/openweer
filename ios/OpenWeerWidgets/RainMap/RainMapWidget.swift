import SwiftUI
import WidgetKit

struct RainMapWidget: Widget {
    static let kind = "nl.openweer.widget.map"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: MapProvider()) { entry in
            RainMapRouter(entry: entry)
                .containerBackground(Color.owSurfaceCard, for: .widget)
        }
        .configurationDisplayName("Regenkaart")
        .description("Live radar voor jouw plek met de regenverwachting.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct MapProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry { WidgetDataLoader.placeholder() }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetDataLoader.snapshot(for: .map))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let timeline = await WidgetDataLoader.timeline(for: .map)
            completion(timeline)
        }
    }
}

private struct RainMapRouter: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemLarge: RainMapLarge(entry: entry)
        default:           RainMapMedium(entry: entry)
        }
    }
}
