import SwiftUI

/// 2×2 grid of stat tiles: Wind · Vochtigheid · UV-index · Zon. Each tile
/// degrades to `—` with a small caption when the underlying field is
/// missing for far-out ECMWF days.
struct DayDetailStatsGrid: View {
    let day: DailyForecast
    let slots: [HourlySlot]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.owInkSecondary)

            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                tile(title: "Wind", icon: "wind", primary: windPrimary, caption: windCaption)
                tile(title: "Vochtigheid", icon: "humidity", primary: humidityPrimary, caption: humidityCaption)
                tile(title: "UV-index", icon: "sun.max.fill", primary: uvPrimary, caption: uvCaption)
                tile(title: "Zon", icon: "sunrise.fill", primary: sunPrimary, caption: sunCaption)
            }
        }
    }

    @ViewBuilder
    private func tile(title: String, icon: String, primary: String, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.owInkSecondary)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.owInkSecondary)
            }
            Text(primary)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.owInkPrimary)
                .monospacedDigit()
            if let caption {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.owInkSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.owSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Wind

    private var windPrimary: String {
        if let peak = slots.compactMap(\.windSpeedKph).max() {
            return String(format: "%.0f km/u", peak)
        }
        if let kph = day.windMaxKph {
            return String(format: "%.0f km/u", kph)
        }
        return "—"
    }

    private var windCaption: String? {
        let gust = slots.compactMap(\.windGustsKph).max()
        let dir = dominantWindDirection ?? day.windDirectionDeg
        var parts: [String] = []
        if let dir { parts.append(compass(forDeg: dir)) }
        if let gust, gust > 0 { parts.append(String(format: "windstoten %.0f km/u", gust)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var dominantWindDirection: Int? {
        let dirs = slots.compactMap(\.windDirectionDeg)
        guard !dirs.isEmpty else { return nil }
        // Circular mean via unit vectors.
        let radians = dirs.map { Double($0) * .pi / 180 }
        let x = radians.map(cos).reduce(0, +) / Double(radians.count)
        let y = radians.map(sin).reduce(0, +) / Double(radians.count)
        var deg = atan2(y, x) * 180 / .pi
        if deg < 0 { deg += 360 }
        return Int(deg.rounded())
    }

    // MARK: - Humidity

    private var humidityPrimary: String {
        let vals = slots.compactMap(\.relativeHumidityPct)
        guard !vals.isEmpty else { return "—" }
        let mean = Double(vals.reduce(0, +)) / Double(vals.count)
        return "\(Int(mean.rounded()))%"
    }

    private var humidityCaption: String? {
        let vals = slots.compactMap(\.relativeHumidityPct)
        guard let lo = vals.min(), let hi = vals.max() else { return nil }
        return "\(lo)% – \(hi)%"
    }

    // MARK: - UV

    private var uvPrimary: String {
        if let peak = slots.compactMap(\.uvIndex).max() {
            return String(format: "%.0f", peak)
        }
        return "—"
    }

    private var uvCaption: String? {
        guard let peak = slots.compactMap(\.uvIndex).max() else { return nil }
        switch peak {
        case ..<3:   return "Laag"
        case ..<6:   return "Matig"
        case ..<8:   return "Hoog"
        case ..<11:  return "Zeer hoog"
        default:     return "Extreem"
        }
    }

    // MARK: - Sunrise / Sunset

    private var sunPrimary: String {
        HourlyStripCard.formatHHMM(day.sunrise) ?? "—"
    }

    private var sunCaption: String? {
        if let set = HourlyStripCard.formatHHMM(day.sunset) {
            return "onder \(set)"
        }
        return nil
    }

    private func compass(forDeg deg: Int) -> String {
        let points = ["N", "NO", "O", "ZO", "Z", "ZW", "W", "NW"]
        let normalised = ((deg % 360) + 360) % 360
        let idx = Int(((Double(normalised) + 22.5) / 45).rounded(.down)) % 8
        return points[idx]
    }
}
