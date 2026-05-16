import SwiftUI
import WidgetKit

struct CurrentAccessoryCircular: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                ConditionGlyph(kind: entry.weather?.current.condition ?? .unknown, size: 18)
                Text(WidgetFormatting.temperature(entry.weather?.current.temperatureC))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
    }
}

struct CurrentAccessoryRectangular: View {
    let entry: WidgetEntry

    var body: some View {
        HStack(alignment: .center, spacing: WidgetTheme.gap) {
            ConditionGlyph(kind: entry.weather?.current.condition ?? .unknown, size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(rectangularHeadline)
                    .font(.headline)
                    .lineLimit(1)
                Text(rectangularSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var rectangularHeadline: String {
        let t = WidgetFormatting.temperature(entry.weather?.current.temperatureC)
        let label = entry.weather?.current.conditionLabel ?? "—"
        return "\(t)  \(label)"
    }

    private var rectangularSubtitle: String {
        WidgetFormatting.rainHeadline(rain: entry.rain)
    }
}

struct CurrentAccessoryInline: View {
    let entry: WidgetEntry

    var body: some View {
        let temp = WidgetFormatting.temperature(entry.weather?.current.temperatureC)
        let verdict = WidgetFormatting.outsideVerdict(rain: entry.rain, now: entry.date)
        Text("\(temp) · \(verdict)")
    }
}
