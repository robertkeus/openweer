import SwiftUI
import WidgetKit

struct CurrentAccessoryCircular: View {
    let entry: WidgetEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                ConditionGlyph(kind: entry.weather?.current.condition ?? .unknown, size: 22)
                Text(WidgetFormatting.temperature(entry.weather?.current.temperatureC))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
        }
    }
}

struct CurrentAccessoryRectangular: View {
    let entry: WidgetEntry

    var body: some View {
        HStack(spacing: 8) {
            ConditionGlyph(kind: entry.weather?.current.condition ?? .unknown, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(WidgetFormatting.temperature(entry.weather?.current.temperatureC) + " " +
                     (entry.weather?.current.conditionLabel ?? ""))
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.location.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

struct CurrentAccessoryInline: View {
    let entry: WidgetEntry

    var body: some View {
        let temp = WidgetFormatting.temperature(entry.weather?.current.temperatureC)
        let label = entry.weather?.current.conditionLabel ?? "—"
        Text("\(temp) · \(label)")
    }
}
