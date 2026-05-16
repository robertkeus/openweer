import SwiftUI

struct CurrentConditionsSmall: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ConditionGlyph(kind: condition, size: 44)
            Spacer(minLength: 0)
            Text(temperature)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.owInkPrimary)
                .unredacted()
            Text(entry.location.name)
                .font(.caption)
                .foregroundStyle(Color.owInkSecondary)
                .lineLimit(1)
                .unredacted()
            if entry.weather == nil {
                Text("Tik om te openen")
                    .font(.caption2)
                    .foregroundStyle(Color.owInkSecondary)
                    .lineLimit(1)
                    .unredacted()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var condition: ConditionKind {
        entry.weather?.current.condition ?? .unknown
    }
    private var temperature: String {
        WidgetFormatting.temperature(entry.weather?.current.temperatureC)
    }
}

struct CurrentConditionsMedium: View {
    let entry: WidgetEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                ConditionGlyph(kind: condition, size: 50)
                Text(entry.location.name)
                    .font(.caption)
                    .foregroundStyle(Color.owInkSecondary)
                    .lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(temperature)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.owInkPrimary)
                    Spacer()
                    Text(WidgetFormatting.updatedAt(entry.weather?.current.observedAt))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.owInkSecondary)
                }
                if let feels = entry.weather?.current.feelsLikeC {
                    Text("Voelt als \(WidgetFormatting.temperature(feels))")
                        .font(.caption)
                        .foregroundStyle(Color.owInkSecondary)
                }
                Text(rainHeadline)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.owAccent)
                    .lineLimit(1)
                Text(WidgetFormatting.outsideVerdict(rain: entry.rain, now: entry.date))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.owInkPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var condition: ConditionKind {
        entry.weather?.current.condition ?? .unknown
    }
    private var temperature: String {
        WidgetFormatting.temperature(entry.weather?.current.temperatureC)
    }
    private var rainHeadline: String {
        WidgetFormatting.rainHeadline(rain: entry.rain)
    }
}

/// Shared formatting bits so each view stays focused on layout.
enum WidgetFormatting {
    static func temperature(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))°"
    }

    static func rainHeadline(rain: RainResponse?) -> String {
        guard let rain else { return "Open OpenWeer om te laden" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        if let first = rain.samples.first(where: { $0.minutesAhead > 0 && $0.mmPerHour >= 0.1 }) {
            return "Regen om \(fmt.string(from: first.validAt))"
        }
        return "Geen regen verwacht"
    }

    /// "11:23" timestamp prefixed for a "bijgewerkt" caption.
    static func updatedAt(_ date: Date?) -> String {
        guard let date else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    /// 15-minute go/no-go verdict — short enough for a small widget caption.
    static func outsideVerdict(rain: RainResponse?, now: Date) -> String {
        guard let rain else { return "" }
        return rain.outsideVerdict(now: now)
    }
}
