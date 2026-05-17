import SwiftUI

/// Single column inside the horizontal hourly strip — fixed 56 pt wide,
/// stacking HH label · weather glyph · optional precip % · temperature.
struct HourCell: View {
    let label: String
    let kind: ConditionKind
    let temperatureC: Double?
    let precipitationProbabilityPct: Int?
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: isHighlighted ? .semibold : .medium))
                .foregroundStyle(isHighlighted ? Color.owAccent : Color.owInkSecondary)
                .monospacedDigit()
            ConditionGlyph(kind: kind, size: 28)
            if let pct = precipitationProbabilityPct, pct >= 10 {
                Text("\(pct)%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.owAccent)
                    .monospacedDigit()
            } else {
                Text(" ")
                    .font(.system(size: 11))
            }
            Text(temperatureText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.owInkPrimary)
                .monospacedDigit()
        }
        .frame(width: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var temperatureText: String {
        guard let v = temperatureC else { return "—" }
        return String(format: "%.0f°", v).replacingOccurrences(of: "-", with: "−")
    }

    private var accessibilityText: String {
        var parts: [String] = [label]
        switch kind {
        case .clear:        parts.append("helder")
        case .partlyCloudy: parts.append("half bewolkt")
        case .cloudy:       parts.append("bewolkt")
        case .fog:          parts.append("mist")
        case .drizzle:      parts.append("motregen")
        case .rain:         parts.append("regen")
        case .thunder:      parts.append("onweer")
        case .snow:         parts.append("sneeuw")
        case .unknown:      break
        }
        if let v = temperatureC {
            parts.append(String(format: "%.0f graden", v))
        }
        if let pct = precipitationProbabilityPct, pct >= 10 {
            parts.append("\(pct) procent kans op regen")
        }
        return parts.joined(separator: ", ")
    }
}
