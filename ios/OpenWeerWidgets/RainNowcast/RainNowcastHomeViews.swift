import SwiftUI

struct RainNowcastSmall: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.location.name)
                    .font(.caption)
                    .foregroundStyle(Color.owInkSecondary)
                    .lineLimit(1)
                Spacer()
                Text(WidgetFormatting.updatedAt(entry.rain?.analysisAt))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.owInkSecondary)
            }
            Text(WidgetFormatting.rainHeadline(rain: entry.rain))
                .font(.headline)
                .foregroundStyle(Color.owInkPrimary)
                .lineLimit(2)
            Text(WidgetFormatting.outsideVerdict(rain: entry.rain, now: entry.date))
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.owAccent)
                .lineLimit(1)
            Spacer(minLength: 2)
            RainBarChart(samples: entry.rain?.samples ?? [])
                .frame(maxWidth: .infinity)
                .frame(height: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct RainNowcastMedium: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(WidgetFormatting.rainHeadline(rain: entry.rain))
                        .font(.headline)
                        .foregroundStyle(Color.owInkPrimary)
                        .lineLimit(1)
                    Text(entry.location.name)
                        .font(.caption)
                        .foregroundStyle(Color.owInkSecondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(totalLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.owInkSecondary)
                    Text(WidgetFormatting.updatedAt(entry.rain?.analysisAt))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.owInkSecondary)
                }
            }
            Text(WidgetFormatting.outsideVerdict(rain: entry.rain, now: entry.date))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.owAccent)
                .lineLimit(1)
            RainBarChart(samples: entry.rain?.samples ?? [])
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            RainAxisLabels(samples: entry.rain?.samples ?? [])
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Color.owInkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var totalLabel: String {
        let total = (entry.rain?.samples ?? []).reduce(0.0) { $0 + max($1.mmPerHour, 0) } / 12
        return String(format: "%.1f mm", total)
    }
}

/// 4 evenly-spaced timestamps along the bar chart.
struct RainAxisLabels: View {
    let samples: [RainSample]

    var body: some View {
        let stops = pick(from: samples, count: 4)
        HStack {
            ForEach(stops.indices, id: \.self) { i in
                Text(format(stops[i]))
                Spacer(minLength: 0)
                    .hidden()
                    .frame(maxWidth: i == stops.count - 1 ? 0 : .infinity)
            }
        }
    }

    private func pick(from xs: [RainSample], count: Int) -> [RainSample] {
        guard xs.count > count else { return xs }
        let step = max(1, xs.count / (count - 1))
        var out: [RainSample] = []
        for i in stride(from: 0, to: xs.count, by: step) { out.append(xs[i]) }
        if let last = xs.last, out.last?.minutesAhead != last.minutesAhead { out.append(last) }
        return Array(out.prefix(count))
    }

    private func format(_ s: RainSample) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: s.validAt)
    }
}
