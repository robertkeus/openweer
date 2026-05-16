import SwiftUI
import WidgetKit

struct CurrentConditionsWidget: Widget {
    static let kind = "nl.openweer.widget.current"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: CurrentProvider()) { entry in
            CurrentConditionsRouter(entry: entry)
                .containerBackground(Color.owSurfaceCard, for: .widget)
        }
        .configurationDisplayName("Huidig weer")
        .description("Temperatuur en weersbeeld voor jouw plek.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

private struct CurrentProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry { WidgetDataLoader.placeholder() }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        completion(WidgetDataLoader.snapshot(for: .current))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        Task {
            let timeline = await WidgetDataLoader.timeline(for: .current)
            completion(timeline)
        }
    }
}

/// Routes to the right view per family. Centralised so the StaticConfiguration
/// only needs one entry view.
private struct CurrentConditionsRouter: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:        CurrentConditionsSmall(entry: entry)
        case .systemMedium:       CurrentConditionsMedium(entry: entry)
        case .accessoryCircular:  CurrentAccessoryCircular(entry: entry)
        case .accessoryRectangular: CurrentAccessoryRectangular(entry: entry)
        case .accessoryInline:    CurrentAccessoryInline(entry: entry)
        default:                  CurrentConditionsSmall(entry: entry)
        }
    }
}
