import SwiftUI
import WidgetKit

struct RainAccessoryRectangular: View {
    let entry: WidgetEntry

    var body: some View {
        let summary = RainSummary(rain: entry.rain, now: entry.date)
        VStack(alignment: .leading, spacing: 1) {
            Text(summary.hero)
                .font(.headline)
                .lineLimit(1)
            Text(summary.detail)
                .font(.caption2)
                .lineLimit(1)
            let snap = RainWindow.recent(from: entry.rain?.samples ?? [],
                                         now: entry.date)
            RainBarChart(samples: snap.samples, nowIndex: snap.nowIndex)
                .frame(height: 12)
        }
    }
}

struct RainAccessoryInline: View {
    let entry: WidgetEntry

    var body: some View {
        let summary = RainSummary(rain: entry.rain, now: entry.date)
        if let mins = summary.countdownMinutes {
            Text("\(summary.hero) · \(mins) min")
        } else {
            Text(summary.hero)
        }
    }
}
