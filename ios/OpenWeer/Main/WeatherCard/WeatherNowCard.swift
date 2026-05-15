import SwiftUI

struct WeatherNowCard: View {
    let response: WeatherResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(response.station.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.owInkSecondary)
                    Text(response.current.conditionLabel.capitalized)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.owInkPrimary)
                }
                Spacer()
                ConditionGlyph(kind: response.current.condition, size: 48)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(formatTemp(response.current.temperatureC))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Color.owInkPrimary)
                if let feels = response.current.feelsLikeC {
                    Text("voelt als \(formatTemp(feels))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.owInkSecondary)
                }
            }

            HStack(spacing: 18) {
                stat("wind", windText)
                stat("humidity", humidityText)
                stat("rain", rainText)
                stat("pressure", pressureText)
            }
        }
        .padding(16)
        .background(Color.owSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func stat(_ icon: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: iconName(for: icon))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.owInkSecondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.owInkSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func iconName(for kind: String) -> String {
        switch kind {
        case "wind":     return "wind"
        case "humidity": return "humidity"
        case "rain":     return "drop"
        case "pressure": return "barometer"
        default:         return "circle"
        }
    }

    private func formatTemp(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.0f°", v)
    }

    private var windText: String {
        if let bft = response.current.windSpeedBft,
           let dir = response.current.windDirectionCompass {
            return "\(bft) Bft \(dir)"
        }
        if let mps = response.current.windSpeedMps {
            return String(format: "%.1f m/s", mps)
        }
        return "—"
    }

    private var humidityText: String {
        if let h = response.current.humidityPct {
            return "\(Int(h))%"
        }
        return "—"
    }

    private var rainText: String {
        if let mm = response.current.rainfall1hMm {
            return String(format: "%.1f mm/u", mm)
        }
        return "0 mm"
    }

    private var pressureText: String {
        if let p = response.current.pressureHpa {
            return "\(Int(p)) hPa"
        }
        return "—"
    }
}
