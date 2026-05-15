import SwiftUI

/// Compact "current weather at a glance" chip — location name + condition icon
/// + temperature. Designed to live at the very top of the bottom sheet so the
/// user sees the current weather even at the medium detent.
struct WeatherNowChip: View {
    let locationName: String
    let weather: WeatherResponse?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(locationName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.owInkPrimary)
                if let weather {
                    Text(subtitle(weather))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.owInkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let weather {
                HStack(spacing: 8) {
                    ConditionGlyph(kind: weather.current.condition, size: 34)
                    Text(formatTemp(weather.current.temperatureC))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.owInkPrimary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func formatTemp(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.0f°", v)
    }

    private func subtitle(_ w: WeatherResponse) -> String {
        var parts: [String] = [w.current.conditionLabel.capitalized]
        if let bft = w.current.windSpeedBft, let dir = w.current.windDirectionCompass {
            parts.append("\(bft) Bft \(dir)")
        }
        parts.append(w.station.name)
        return parts.joined(separator: " · ")
    }
}
