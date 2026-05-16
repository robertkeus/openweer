import SwiftUI
import WidgetKit

struct ForecastWidget: Widget {
    static let kind = "nl.openweer.widget.forecast"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ForecastProvider()) { entry in
            ForecastRouter(entry: entry)
                .containerBackground(Color.owSurfaceCard, for: .widget)
        }
        .configurationDisplayName("Verwachting")
        .description("De komende dagen in één oogopslag.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct ForecastProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry { WidgetDataLoader.placeholder() }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetDataLoader.snapshot(for: .forecast))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let timeline = await WidgetDataLoader.timeline(for: .forecast)
            completion(timeline)
        }
    }
}

private struct ForecastRouter: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemLarge: ForecastLarge(entry: entry)
        default:           ForecastMedium(entry: entry)
        }
    }
}
