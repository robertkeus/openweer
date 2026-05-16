import SwiftUI

struct RainActivityLockScreen: View {
    let attributes: RainActivityAttributes
    let state: RainActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                ConditionGlyph(kind: condition, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.headline)
                        .font(.headline)
                        .foregroundStyle(Color.owInkPrimary)
                        .lineLimit(1)
                    Text(attributes.locationName)
                        .font(.caption)
                        .foregroundStyle(Color.owInkSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(RainActivityFormatting.minutesLabel(state: state))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.owInkSecondary)
            }
            RainBarChart(values: state.intensities)
                .frame(height: 36)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var condition: ConditionKind {
        ConditionKind(rawValue: state.conditionRaw) ?? .rain
    }
}

struct RainExpandedLeading: View {
    let state: RainActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ConditionGlyph(kind: condition, size: 28)
            Text(state.headline)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
    }

    private var condition: ConditionKind {
        ConditionKind(rawValue: state.conditionRaw) ?? .rain
    }
}

struct RainExpandedTrailing: View {
    let state: RainActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(RainActivityFormatting.minutesLabel(state: state))
                .font(.title3.monospacedDigit())
                .foregroundStyle(Color.owAccent)
            Text("tot regen")
                .font(.caption2)
                .foregroundStyle(Color.owInkSecondary)
        }
    }
}

struct RainExpandedBottom: View {
    let state: RainActivityAttributes.ContentState

    var body: some View {
        RainBarChart(values: state.intensities)
            .frame(height: 36)
    }
}

enum RainActivityFormatting {
    /// Used in the Dynamic Island compact trailing slot — must fit in roughly
    /// 4 characters.
    static func compactTrailing(state: RainActivityAttributes.ContentState) -> String {
        if let startsAt = state.startsAt {
            let mins = max(0, Int(startsAt.timeIntervalSinceNow / 60))
            return "\(mins)m"
        }
        if let stopsAt = state.stopsAt {
            let mins = max(0, Int(stopsAt.timeIntervalSinceNow / 60))
            return "↓\(mins)m"
        }
        return "—"
    }

    static func minutesLabel(state: RainActivityAttributes.ContentState) -> String {
        if let startsAt = state.startsAt {
            let mins = max(0, Int(startsAt.timeIntervalSinceNow / 60))
            return "\(mins) min"
        }
        if let stopsAt = state.stopsAt {
            let mins = max(0, Int(stopsAt.timeIntervalSinceNow / 60))
            return "stopt \(mins) min"
        }
        return "geen"
    }
}
