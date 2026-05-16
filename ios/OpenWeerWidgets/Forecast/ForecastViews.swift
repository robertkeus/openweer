import SwiftUI

// MARK: - Medium

struct ForecastMedium: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.gap) {
            header
            Spacer(minLength: 0)
            HStack(alignment: .top, spacing: 6) {
                ForEach(days(count: 4)) { day in
                    ForecastDayCell(day: day, isToday: isToday(day))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.location.name)
                .font(WidgetTheme.eyebrow)
                .tracking(0.6)
                .foregroundStyle(Color.owInkSecondary)
                .lineLimit(1)
                .unredacted()
            Spacer()
            Text("Verwachting")
                .font(WidgetTheme.meta)
                .foregroundStyle(Color.owInkSecondary)
                .unredacted()
        }
    }

    private func days(count: Int) -> [DailyForecast] {
        Array((entry.forecast?.days ?? []).prefix(count))
    }
    private func isToday(_ day: DailyForecast) -> Bool {
        ForecastFormatting.isToday(day.date)
    }
}

// MARK: - Large

struct ForecastLarge: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetTheme.gap) {
            header
            Divider().opacity(0.4)
            VStack(spacing: 8) {
                ForEach(days(count: 6)) { day in
                    ForecastDayRow(day: day,
                                   isToday: isToday(day),
                                   range: tempRange)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.location.name)
                    .font(WidgetTheme.eyebrow)
                    .tracking(0.6)
                    .foregroundStyle(Color.owInkSecondary)
                    .lineLimit(1)
                    .unredacted()
                Text("Komende dagen")
                    .font(WidgetTheme.statement)
                    .foregroundStyle(Color.owInkPrimary)
                    .lineLimit(1)
                    .unredacted()
            }
            Spacer()
            if let summary = tonightSummary {
                Text(summary)
                    .font(WidgetTheme.meta)
                    .foregroundStyle(Color.owInkSecondary)
            }
        }
    }

    private var tonightSummary: String? {
        guard let day = entry.forecast?.days.first,
              let max = day.temperatureMaxC,
              let min = day.temperatureMinC else { return nil }
        return "Vandaag \(Int(min.rounded()))° – \(Int(max.rounded()))°"
    }

    private func days(count: Int) -> [DailyForecast] {
        Array((entry.forecast?.days ?? []).prefix(count))
    }
    private func isToday(_ day: DailyForecast) -> Bool {
        ForecastFormatting.isToday(day.date)
    }

    /// Min/max temperature across the entire window — used to scale the
    /// horizontal range bars in `ForecastDayRow`.
    private var tempRange: ClosedRange<Double>? {
        let days = (entry.forecast?.days ?? []).prefix(6)
        let mins = days.compactMap { $0.temperatureMinC }
        let maxs = days.compactMap { $0.temperatureMaxC }
        guard let lo = mins.min(), let hi = maxs.max(), hi > lo else { return nil }
        return lo...hi
    }
}

// MARK: - Day cell (medium)

private struct ForecastDayCell: View {
    let day: DailyForecast
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(ForecastFormatting.shortDay(from: day.date, today: isToday))
                .font(WidgetTheme.eyebrow)
                .tracking(0.6)
                .foregroundStyle(isToday ? Color.owAccent : Color.owInkSecondary)
            ConditionGlyph(kind: WeatherIcon.kind(forWmoCode: day.weatherCode), size: 30)
            Text(ForecastFormatting.minMax(day))
                .font(WidgetTheme.support.monospacedDigit())
                .foregroundStyle(Color.owInkPrimary)
                .lineLimit(1)
            if let p = day.precipitationProbabilityPct, p >= 10 {
                Text("\(p)%")
                    .font(WidgetTheme.meta)
                    .foregroundStyle(Color.owAccent)
            } else {
                Text(" ")
                    .font(WidgetTheme.meta)
            }
        }
    }
}

// MARK: - Day row (large)

private struct ForecastDayRow: View {
    let day: DailyForecast
    let isToday: Bool
    let range: ClosedRange<Double>?

    var body: some View {
        HStack(spacing: WidgetTheme.gap) {
            Text(ForecastFormatting.weekdayLong(from: day.date, today: isToday))
                .font(WidgetTheme.support)
                .foregroundStyle(isToday ? Color.owAccent : Color.owInkPrimary)
                .frame(width: 50, alignment: .leading)

            ConditionGlyph(kind: WeatherIcon.kind(forWmoCode: day.weatherCode), size: 22)
                .frame(width: 26)

            if let mn = day.temperatureMinC {
                Text("\(Int(mn.rounded()))°")
                    .font(WidgetTheme.support.monospacedDigit())
                    .foregroundStyle(Color.owInkSecondary)
                    .frame(width: 24, alignment: .trailing)
            }

            tempBar
                .frame(height: 6)

            if let mx = day.temperatureMaxC {
                Text("\(Int(mx.rounded()))°")
                    .font(WidgetTheme.support.monospacedDigit())
                    .foregroundStyle(Color.owInkPrimary)
                    .frame(width: 24, alignment: .leading)
            }

            if let p = day.precipitationProbabilityPct, p >= 10 {
                Text("\(p)%")
                    .font(WidgetTheme.meta)
                    .foregroundStyle(Color.owAccent)
                    .frame(width: 30, alignment: .trailing)
            } else {
                Spacer().frame(width: 30)
            }
        }
    }

    private var tempBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.owInkSecondary.opacity(0.15))
                if let range,
                   let mn = day.temperatureMinC,
                   let mx = day.temperatureMaxC {
                    let span = range.upperBound - range.lowerBound
                    let lead = (mn - range.lowerBound) / span
                    let width = (mx - mn) / span
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.owAccent.opacity(0.65), Color.owSun.opacity(0.9)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: max(4, geo.size.width * CGFloat(width)))
                        .offset(x: geo.size.width * CGFloat(lead))
                }
            }
        }
    }
}

// MARK: - Formatting

enum ForecastFormatting {
    private static let inFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func isToday(_ yyyyMMdd: String) -> Bool {
        guard let date = inFmt.date(from: yyyyMMdd) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    static func shortDay(from yyyyMMdd: String, today: Bool) -> String {
        if today { return "Vandaag" }
        return formatted(yyyyMMdd, pattern: "EEE")
    }

    static func weekdayLong(from yyyyMMdd: String, today: Bool) -> String {
        if today { return "Vandaag" }
        return formatted(yyyyMMdd, pattern: "EEEE")
    }

    static func minMax(_ day: DailyForecast) -> String {
        let mx = day.temperatureMaxC.map { "\(Int($0.rounded()))°" } ?? "—"
        let mn = day.temperatureMinC.map { "\(Int($0.rounded()))°" } ?? "—"
        return "\(mx) / \(mn)"
    }

    private static func formatted(_ yyyyMMdd: String, pattern: String) -> String {
        guard let date = inFmt.date(from: yyyyMMdd) else { return yyyyMMdd }
        let out = DateFormatter()
        out.locale = Locale(identifier: "nl_NL")
        out.dateFormat = pattern
        return out.string(from: date).capitalized
    }
}
