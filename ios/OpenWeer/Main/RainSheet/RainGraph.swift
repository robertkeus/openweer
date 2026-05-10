import SwiftUI

struct RainGraph: View {
    let samples: [RainSample]
    let analysisAt: Date
    var maxMmPerHour: Double = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Canvas { context, size in
                guard !samples.isEmpty else { return }
                let count = CGFloat(samples.count)
                let spacing: CGFloat = 1
                let barWidth = max(1, (size.width - spacing * (count - 1)) / count)
                let scale = size.height
                for (i, s) in samples.enumerated() {
                    let normalised = min(max(s.mmPerHour, 0), maxMmPerHour) / maxMmPerHour
                    let h = max(2, scale * normalised)
                    let x = CGFloat(i) * (barWidth + spacing)
                    let rect = CGRect(x: x, y: scale - h, width: barWidth, height: h)
                    context.fill(Path(rect), with: .color(RainIntensity.color(forMmPerHour: s.mmPerHour)))
                }
            }
            .frame(height: 110)
            .accessibilityLabel(accessibilityLabel)

            HStack {
                ForEach(timeMarkers, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.owInkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var timeMarkers: [String] {
        guard !samples.isEmpty else { return [] }
        let totalMinutes = (samples.last?.minutesAhead ?? 0) - (samples.first?.minutesAhead ?? 0)
        let stops = [0, totalMinutes / 4, totalMinutes / 2, (3 * totalMinutes) / 4, totalMinutes]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        formatter.dateFormat = "HH:mm"
        return stops.map { offset in
            let date = analysisAt.addingTimeInterval(TimeInterval(offset * 60))
            return formatter.string(from: date)
        }
    }

    private var accessibilityLabel: String {
        let peak = samples.max(by: { $0.mmPerHour < $1.mmPerHour })
        if let peak, peak.mmPerHour >= 0.1 {
            return "Regenvoorspelling: piek \(String(format: "%.1f", peak.mmPerHour)) mm per uur over \(peak.minutesAhead) minuten"
        }
        return "Geen regen voorspeld in de komende twee uur"
    }
}
