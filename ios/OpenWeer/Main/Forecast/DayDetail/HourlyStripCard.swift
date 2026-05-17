import SwiftUI

/// Horizontal scroll of hour cells with optional inline sunrise/sunset
/// markers. When `slots` is empty, renders a skeleton placeholder row.
struct HourlyStripCard: View {
    let slots: [HourlySlot]
    let day: DailyForecast
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per uur")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.owInkSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if slots.isEmpty {
                        skeletonRow
                    } else {
                        ForEach(items, id: \.self) { item in
                            switch item {
                            case .hour(let slot):
                                HourCell(
                                    label: hourLabel(for: slot),
                                    kind: WeatherIcon.kind(forWmoCode: slot.weatherCode),
                                    temperatureC: slot.temperatureC,
                                    precipitationProbabilityPct: slot.precipitationProbabilityPct,
                                    isHighlighted: isToday && isCurrentHour(slot)
                                )
                            case .sun(let symbol, let label):
                                sunCell(symbol: symbol, label: label)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .background(Color.owSurfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    private enum Item: Hashable {
        case hour(HourlySlot)
        case sun(symbol: String, label: String)
    }

    /// Inject inline sunrise/sunset cells right after the matching hour slot.
    private var items: [Item] {
        var out: [Item] = []
        let sunriseHour = HourlyStripCard.parseHour(day.sunrise)
        let sunsetHour = HourlyStripCard.parseHour(day.sunset)
        let cal = Calendar.amsterdam
        for slot in slots {
            let hour = cal.component(.hour, from: slot.time)
            out.append(.hour(slot))
            if sunriseHour == hour, let label = HourlyStripCard.formatHHMM(day.sunrise) {
                out.append(.sun(symbol: "sunrise.fill", label: label))
            }
            if sunsetHour == hour, let label = HourlyStripCard.formatHHMM(day.sunset) {
                out.append(.sun(symbol: "sunset.fill", label: label))
            }
        }
        return out
    }

    @ViewBuilder
    private func sunCell(symbol: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(symbol == "sunrise.fill" ? "Op" : "Onder")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.owInkSecondary)
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(Color.owSun)
                .frame(height: 28)
            Text(" ")
                .font(.system(size: 11))
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.owInkPrimary)
                .monospacedDigit()
        }
        .frame(width: 56)
        .accessibilityLabel(symbol == "sunrise.fill" ? "Zonsopgang \(label)" : "Zonsondergang \(label)")
    }

    private var skeletonRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<10, id: \.self) { _ in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.owInkSecondary.opacity(0.18)).frame(width: 26, height: 12)
                    RoundedRectangle(cornerRadius: 6).fill(Color.owInkSecondary.opacity(0.14)).frame(width: 28, height: 28)
                    RoundedRectangle(cornerRadius: 4).fill(Color.owInkSecondary.opacity(0.10)).frame(width: 24, height: 11)
                    RoundedRectangle(cornerRadius: 4).fill(Color.owInkSecondary.opacity(0.18)).frame(width: 28, height: 14)
                }
                .frame(width: 56)
            }
        }
        .redacted(reason: .placeholder)
    }

    private func hourLabel(for slot: HourlySlot) -> String {
        if isToday && isCurrentHour(slot) { return "Nu" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        f.dateFormat = "HH"
        return f.string(from: slot.time)
    }

    private func isCurrentHour(_ slot: HourlySlot) -> Bool {
        let cal = Calendar.amsterdam
        return cal.component(.hour, from: slot.time) == cal.component(.hour, from: Date())
            && cal.isDate(slot.time, inSameDayAs: Date())
    }

    /// Open-Meteo emits sunrise/sunset as `"yyyy-MM-ddTHH:mm"`. Extract HH.
    static func parseHour(_ iso: String?) -> Int? {
        guard let iso else { return nil }
        guard let tIdx = iso.firstIndex(of: "T") else { return nil }
        let after = iso.index(after: tIdx)
        let timePart = iso[after...]
        let comps = timePart.split(separator: ":")
        guard let first = comps.first, let h = Int(first) else { return nil }
        return h
    }

    /// Render the `HH:mm` part of `"yyyy-MM-ddTHH:mm"`.
    static func formatHHMM(_ iso: String?) -> String? {
        guard let iso else { return nil }
        guard let tIdx = iso.firstIndex(of: "T") else { return nil }
        return String(iso[iso.index(after: tIdx)...].prefix(5))
    }
}

extension Calendar {
    static let amsterdam: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return c
    }()
}
