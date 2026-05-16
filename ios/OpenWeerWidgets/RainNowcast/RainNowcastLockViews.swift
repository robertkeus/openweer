import SwiftUI
import WidgetKit

struct RainAccessoryRectangular: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(WidgetFormatting.rainHeadline(rain: entry.rain))
                .font(.headline)
                .lineLimit(1)
            Text(entry.location.name)
                .font(.caption2)
                .lineLimit(1)
            RainBarChart(samples: entry.rain?.samples ?? [])
                .frame(height: 14)
        }
    }
}

struct RainAccessoryInline: View {
    let entry: WidgetEntry

    var body: some View {
        Text(WidgetFormatting.rainHeadline(rain: entry.rain))
    }
}
