import SwiftUI
import WidgetKit

struct RainNowcastWidget: Widget {
    static let kind = "nl.openweer.widget.rain"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RainProvider()) { entry in
            RainNowcastRouter(entry: entry)
                .containerBackground(Color.owSurfaceCard, for: .widget)
        }
        .configurationDisplayName("Regen — 2 uur")
        .description("Neerslag voor de komende twee uur.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryInline
        ])
    }
}

private struct RainProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry { WidgetDataLoader.placeholder() }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetDataLoader.snapshot(for: .rain))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let timeline = await WidgetDataLoader.timeline(for: .rain)
            completion(timeline)
        }
    }
}

private struct RainNowcastRouter: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:          RainNowcastSmall(entry: entry)
        case .systemMedium:         RainNowcastMedium(entry: entry)
        case .accessoryRectangular: RainAccessoryRectangular(entry: entry)
        case .accessoryInline:      RainAccessoryInline(entry: entry)
        default:                    RainNowcastSmall(entry: entry)
        }
    }
}
