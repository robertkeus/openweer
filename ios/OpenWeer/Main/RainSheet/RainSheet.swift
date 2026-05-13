import SwiftUI

struct RainSheet: View {
    let locationName: String
    let rain: RainResponse?
    let weather: WeatherResponse?
    let forecast: ForecastResponse?
    let isLoading: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                rainCard
                if let weather { WeatherNowCard(response: weather) }
                if let forecast { ForecastList(response: forecast) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.owSurface)
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(locationName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.owInkPrimary)
            if let analysisAt = rain?.analysisAt {
                Text(analysisLabel(analysisAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.owInkSecondary)
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var rainCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Regen — komende 2 uur")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.owInkPrimary)
                Spacer()
                if let rain {
                    Text(headlineText(for: rain))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.owInkSecondary)
                }
            }
            if let rain {
                RainGraph(samples: rain.samples, analysisAt: rain.analysisAt)
                RainLegend()
            } else if isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 110)
            } else {
                Text("Geen gegevens beschikbaar")
                    .foregroundStyle(Color.owInkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 110)
            }
        }
        .padding(16)
        .background(Color.owSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func analysisLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.dateFormat = "HH:mm"
        return "Bijgewerkt \(f.string(from: date))"
    }

    private func headlineText(for rain: RainResponse) -> String {
        let peak = rain.samples.max(by: { $0.mmPerHour < $1.mmPerHour })
        guard let peak, peak.mmPerHour >= 0.1 else {
            return "Droog"
        }
        return String(format: "Piek %.1f mm/u", peak.mmPerHour)
    }
}
