import SwiftUI

struct DailyForecastRow: View {
    let day: DailyForecast
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(dayLabel)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.owInkPrimary)
                .frame(width: 64, alignment: .leading)

            ConditionGlyph(kind: WeatherIcon.kind(forWmoCode: day.weatherCode),
                           size: 28)

            Text(conditionLabel)
                .font(.system(size: 14))
                .foregroundStyle(Color.owInkSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let pct = day.precipitationProbabilityPct, pct >= 10 {
                Text("\(pct)%")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.owAccent)
            }

            HStack(spacing: 6) {
                Text(formatTemp(day.temperatureMaxC))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.owInkPrimary)
                Text(formatTemp(day.temperatureMinC))
                    .font(.system(size: 14))
                    .foregroundStyle(Color.owInkSecondary)
            }
            .monospacedDigit()
            .frame(width: 76, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var dayLabel: String {
        if index == 0 { return "Vandaag" }
        if index == 1 { return "Morgen" }
        guard let parsed = DateFormatter.iso8601Day.date(from: day.date) else {
            return day.date
        }
        let comps = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(identifier: "Europe/Amsterdam")!,
            from: parsed
        )
        let weekdayIdx = (comps.weekday ?? 1) - 1  // 1=Sun → 0
        let weekdays = ["zo", "ma", "di", "wo", "do", "vr", "za"]
        let wd = weekdays[max(0, min(6, weekdayIdx))]
        let dom = comps.day ?? 0
        return "\(wd) \(dom)"
    }

    private var conditionLabel: String {
        switch WeatherIcon.kind(forWmoCode: day.weatherCode) {
        case .clear:        return "Helder"
        case .partlyCloudy: return "Half bewolkt"
        case .cloudy:       return "Bewolkt"
        case .fog:          return "Mist"
        case .drizzle:      return "Motregen"
        case .rain:         return "Regen"
        case .thunder:      return "Onweer"
        case .snow:         return "Sneeuw"
        case .unknown:      return "—"
        }
    }

    private func formatTemp(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.0f°", v).replacingOccurrences(of: "-", with: "−")
    }
}

private extension DateFormatter {
    static let iso8601Day: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f
    }()
}
