import SwiftUI

struct RainLegend: View {
    var body: some View {
        HStack(spacing: 6) {
            ForEach(RainIntensity.thresholds, id: \.self) { t in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(RainIntensity.color(forMmPerHour: t))
                        .frame(width: 10, height: 10)
                    Text(label(for: t))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.owInkSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Legenda regen-intensiteit in millimeter per uur")
    }

    private func label(for v: Double) -> String {
        if v >= 1 { return String(format: "%.0f", v) }
        return String(format: "%.1f", v)
    }
}
