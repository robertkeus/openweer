import SwiftUI

struct ForecastMedium: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.location.name)
                .font(.caption)
                .foregroundStyle(Color.owInkSecondary)
                .lineLimit(1)
            HStack(spacing: 10) {
                ForEach(days(count: 3)) { day in
                    ForecastDayCell(day: day)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func days(count: Int) -> [DailyForecast] {
        Array((entry.forecast?.days ?? []).prefix(count))
    }
}

struct ForecastLarge: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.location.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.owInkPrimary)
                    .lineLimit(1)
                Spacer()
                Text("Komende dagen")
                    .font(.caption)
                    .foregroundStyle(Color.owInkSecondary)
            }
            ForEach(days(count: 5)) { day in
                ForecastDayRow(day: day)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func days(count: Int) -> [DailyForecast] {
        Array((entry.forecast?.days ?? []).prefix(count))
    }
}

private struct ForecastDayCell: View {
    let day: DailyForecast

    var body: some View {
        VStack(spacing: 4) {
            Text(ForecastFormatting.shortDay(from: day.date))
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.owInkSecondary)
            ConditionGlyph(kind: WeatherIcon.kind(forWmoCode: day.weatherCode), size: 30)
            Text(ForecastFormatting.minMax(day))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Color.owInkPrimary)
                .lineLimit(1)
            if let p = day.precipitationProbabilityPct {
                Text("\(p)%")
                    .font(.caption2)
                    .foregroundStyle(Color.owAccent)
            }
        }
    }
}

private struct ForecastDayRow: View {
    let day: DailyForecast

    var body: some View {
        HStack(spacing: 10) {
            Text(ForecastFormatting.shortDay(from: day.date))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.owInkSecondary)
                .frame(width: 44, alignment: .leading)
            ConditionGlyph(kind: WeatherIcon.kind(forWmoCode: day.weatherCode), size: 26)
            if let p = day.precipitationProbabilityPct {
                Text("\(p)%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.owAccent)
                    .frame(width: 36, alignment: .leading)
            } else {
                Spacer().frame(width: 36)
            }
            Spacer(minLength: 0)
            Text(ForecastFormatting.minMax(day))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Color.owInkPrimary)
        }
    }
}

enum ForecastFormatting {
    static func shortDay(from yyyyMMdd: String) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        guard let date = inFmt.date(from: yyyyMMdd) else { return yyyyMMdd }
        let outFmt = DateFormatter()
        outFmt.locale = Locale(identifier: "nl_NL")
        outFmt.dateFormat = "EEE"
        return outFmt.string(from: date).capitalized
    }

    static func minMax(_ day: DailyForecast) -> String {
        let mx = day.temperatureMaxC.map { "\(Int($0.rounded()))°" } ?? "—"
        let mn = day.temperatureMinC.map { "\(Int($0.rounded()))°" } ?? "—"
        return "\(mx) / \(mn)"
    }
}
