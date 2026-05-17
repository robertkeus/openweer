import SwiftUI

// MARK: - Small

struct CurrentConditionsSmall: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.gap) {
            HStack(alignment: .top) {
                Text(entry.location.name)
                    .font(WidgetTheme.eyebrow)
                    .tracking(0.6)
                    .foregroundStyle(Color.owInkSecondary)
                    .lineLimit(1)
                    .unredacted()
                Spacer(minLength: 0)
                ConditionGlyph(kind: condition, size: 28)
            }
            Spacer(minLength: 0)
            Text(temperature)
                .font(WidgetTheme.hero(size: 56))
                .foregroundStyle(Color.owInkPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(conditionLabel)
                .font(WidgetTheme.support)
                .foregroundStyle(Color.owInkSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var condition: ConditionKind {
        entry.weather?.current.condition ?? .unknown
    }
    private var temperature: String {
        WidgetFormatting.temperature(entry.weather?.current.temperatureC)
    }
    private var conditionLabel: String {
        entry.weather?.current.conditionLabel ?? "Bezig met laden"
    }
}

// MARK: - Medium

struct CurrentConditionsMedium: View {
    let entry: WidgetEntry

    var body: some View {
        HStack(alignment: .top, spacing: WidgetTheme.block) {
            heroColumn
            Spacer(minLength: 0)
            statsColumn
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var heroColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.location.name)
                .font(WidgetTheme.eyebrow)
                .tracking(0.6)
                .foregroundStyle(Color.owInkSecondary)
                .lineLimit(1)
                .unredacted()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(temperature)
                    .font(WidgetTheme.hero(size: 64))
                    .foregroundStyle(Color.owInkPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            Text(conditionLabel)
                .font(WidgetTheme.support)
                .foregroundStyle(Color.owInkSecondary)
                .lineLimit(1)
            if let feels = entry.weather?.current.feelsLikeC {
                Text("Voelt als \(WidgetFormatting.temperature(feels))")
                    .font(WidgetTheme.meta)
                    .foregroundStyle(Color.owInkSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var statsColumn: some View {
        VStack(alignment: .trailing, spacing: WidgetTheme.gap) {
            ConditionGlyph(kind: condition, size: 56)
            VStack(alignment: .trailing, spacing: 2) {
                Text(verdict)
                    .font(WidgetTheme.statement)
                    .foregroundStyle(Color.owAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let wind = windSummary {
                    Text(wind)
                        .font(WidgetTheme.meta)
                        .foregroundStyle(Color.owInkSecondary)
                }
                Text(updatedAt)
                    .font(WidgetTheme.meta)
                    .foregroundStyle(Color.owInkSecondary)
            }
        }
    }

    private var condition: ConditionKind {
        entry.weather?.current.condition ?? .unknown
    }
    private var temperature: String {
        WidgetFormatting.temperature(entry.weather?.current.temperatureC)
    }
    private var conditionLabel: String {
        entry.weather?.current.conditionLabel ?? "Bezig met laden"
    }
    private var verdict: String {
        WidgetFormatting.outsideVerdict(rain: entry.rain, now: entry.date)
    }
    private var windSummary: String? {
        guard let current = entry.weather?.current,
              let bft = current.windSpeedBft else { return nil }
        if let compass = current.windDirectionCompass {
            return "\(compass) \(bft) bft"
        }
        return "\(bft) bft"
    }
    private var updatedAt: String {
        let value = WidgetFormatting.updatedAt(entry.weather?.current.observedAt,
                                               now: entry.date)
        return value.isEmpty ? "" : "Bijgewerkt \(value)"
    }
}

// MARK: - Formatting

/// Shared formatting bits so each view stays focused on layout.
enum WidgetFormatting {
    static func temperature(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))°"
    }

    static func rainHeadline(rain: RainResponse?) -> String {
        guard let rain else { return "Bezig met laden" }
        switch rain.outlook() {
        case .rainingNow:           return "Het regent nu"
        case .startsSoon(let date): return "Regen om \(hhmm(date))"
        case .stopsSoon(let date):  return "Droog vanaf \(hhmm(date))"
        case .dry:                  return "Geen regen verwacht"
        }
    }

    /// Relative "X min geleden" / "X uur geleden" label. Absolute clock
    /// times mislead when WidgetKit shows a stale entry; relative phrasing
    /// stays truthful no matter how old the data turns out to be.
    static func updatedAt(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "net" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min geleden" }
        let hours = minutes / 60
        return "\(hours) u geleden"
    }

    /// 15-minute go/no-go verdict — short enough for a small widget caption.
    static func outsideVerdict(rain: RainResponse?, now: Date) -> String {
        guard let rain else { return "" }
        return rain.outsideVerdict(now: now)
    }

    static func hhmm(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}
