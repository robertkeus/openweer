import SwiftUI

struct DailyForecastRow: View {
    let day: DailyForecast

    var body: some View {
        HStack(spacing: 12) {
            Text(formattedDay)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 56, alignment: .leading)
                .foregroundStyle(Color.owInkPrimary)

            Image(systemName: WeatherIcon.symbol(forWmoCode: day.weatherCode))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 22))
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(precipText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.owInkSecondary)
                Text(windText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.owInkSecondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Text(formatTemp(day.temperatureMinC))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.owInkSecondary)
                Text("/")
                    .foregroundStyle(Color.owInkSecondary)
                Text(formatTemp(day.temperatureMaxC))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.owInkPrimary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var formattedDay: String {
        let parsed = DateFormatter.iso8601Day.date(from: day.date)
        guard let parsed else { return day.date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: parsed).capitalized
    }

    private var precipText: String {
        let mm = day.precipitationSumMm ?? 0
        let pct = day.precipitationProbabilityPct ?? 0
        return String(format: "%.1f mm · %d%%", mm, pct)
    }

    private var windText: String {
        if let kph = day.windMaxKph {
            return String(format: "%.0f km/u", kph)
        }
        return "—"
    }

    private func formatTemp(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.0f°", v)
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
