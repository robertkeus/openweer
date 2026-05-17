import SwiftUI

/// 24-bar precipitation chart for one day. Reuses the
/// `RainIntensity.color(forMmPerHour:)` palette but is parametrised by hours
/// rather than 5-minute radar samples (so it can't simply reuse `RainGraph`).
struct HourlyRainChart: View {
    let slots: [HourlySlot]
    var maxMmPerHour: Double = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Regen per uur")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.owInkSecondary)
                Spacer()
                if let peak {
                    Text(peakLabel(peak))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.owInkSecondary)
                }
            }

            Canvas { context, size in
                guard !slots.isEmpty else { return }
                let count = CGFloat(slots.count)
                let spacing: CGFloat = 1
                let barWidth = max(1, (size.width - spacing * (count - 1)) / count)
                let scale = size.height
                for (i, s) in slots.enumerated() {
                    let mm = s.precipitationMm ?? 0
                    let normalised = min(max(mm, 0), maxMmPerHour) / maxMmPerHour
                    let h = max(2, scale * normalised)
                    let x = CGFloat(i) * (barWidth + spacing)
                    let rect = CGRect(x: x, y: scale - h, width: barWidth, height: h)
                    context.fill(Path(rect), with: .color(RainIntensity.color(forMmPerHour: mm)))
                }
            }
            .frame(height: 110)
            .accessibilityLabel(accessibilityLabel)

            HStack(spacing: 0) {
                ForEach(Array(timeMarkers.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.owInkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .monospacedDigit()
        }
        .padding(16)
        .background(Color.owSurfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var peak: HourlySlot? {
        slots.compactMap { slot in
            guard let mm = slot.precipitationMm, mm > 0 else { return nil }
            return slot
        }.max(by: { ($0.precipitationMm ?? 0) < ($1.precipitationMm ?? 0) })
    }

    private func peakLabel(_ slot: HourlySlot) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        f.dateFormat = "HH:mm"
        let mm = slot.precipitationMm ?? 0
        return String(format: "piek %.1f mm bij %@", mm, f.string(from: slot.time))
    }

    private var timeMarkers: [String] {
        // Markers at 0/6/12/18 hour positions when present.
        let cal = Calendar.amsterdam
        let targets = [0, 6, 12, 18]
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        f.dateFormat = "HH:mm"
        return targets.map { hour in
            if let slot = slots.first(where: { cal.component(.hour, from: $0.time) == hour }) {
                return f.string(from: slot.time)
            }
            return "—"
        }
    }

    private var accessibilityLabel: String {
        let total = slots.compactMap(\.precipitationMm).reduce(0, +)
        if total < 0.1 {
            return "Geen regen verwacht vandaag"
        }
        guard let peak, let mm = peak.precipitationMm else {
            return "Totaal \(String(format: "%.1f", total)) mm regen verwacht"
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        f.dateFormat = "HH:mm"
        return String(
            format: "Totaal %.1f mm regen, piek %.1f mm bij %@",
            total, mm, f.string(from: peak.time)
        )
    }
}
