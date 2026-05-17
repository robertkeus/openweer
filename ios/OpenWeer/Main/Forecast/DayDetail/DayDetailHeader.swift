import SwiftUI

/// Top card on the day-detail sheet — renders synchronously from `day`,
/// so the sheet has content the moment it slides up. When hourly slots
/// arrive, the small summary line picks them up too.
struct DayDetailHeader: View {
    let day: DailyForecast
    let slots: [HourlySlot]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateSubtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.owInkSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(conditionLabel)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.owInkPrimary)
                if let summary {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.owInkSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .top, spacing: 4) {
                    Text(formatTemp(day.temperatureMaxC))
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Color.owInkPrimary)
                    ConditionGlyph(kind: WeatherIcon.kind(forWmoCode: day.weatherCode), size: 44)
                }
                Text("min \(formatTemp(day.temperatureMinC))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.owInkSecondary)
            }
            .monospacedDigit()
        }
        .padding(16)
        .background(Color.owSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var dateSubtitle: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        guard let date = parser.date(from: day.date) else { return day.date }
        let out = DateFormatter()
        out.locale = Locale(identifier: "nl_NL")
        out.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        out.dateFormat = "EEEE d MMMM"
        return out.string(from: date)
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

    /// Short narrative built from hourly slots when available (total rain
    /// and probability), falling back to daily totals otherwise.
    private var summary: String? {
        if !slots.isEmpty {
            let total = slots.compactMap(\.precipitationMm).reduce(0, +)
            let peakProb = slots.compactMap(\.precipitationProbabilityPct).max() ?? 0
            if total >= 0.1 {
                return String(format: "%.1f mm regen verwacht, piekkans %d%%", total, peakProb)
            }
            if peakProb >= 30 {
                return "Kans op een bui, piek \(peakProb)%"
            }
            return "Geen regen verwacht"
        }
        if let mm = day.precipitationSumMm, mm >= 0.1 {
            return String(format: "%.1f mm regen verwacht", mm)
        }
        if let pct = day.precipitationProbabilityPct, pct >= 30 {
            return "Kans op een bui (\(pct)%)"
        }
        return nil
    }

    private func formatTemp(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.0f°", v).replacingOccurrences(of: "-", with: "−")
    }
}
