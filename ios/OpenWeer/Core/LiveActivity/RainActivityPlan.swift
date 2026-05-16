import Foundation

/// Pure mapping from a `RainResponse` to a decision about the Live Activity.
/// Extracted from the controller so it can be unit-tested without ActivityKit.
struct RainActivityPlan: Sendable {
    enum Action: Sendable { case start, update, end, noop }

    let action: Action
    let state: RainActivityAttributes.ContentState

    static func from(rain: RainResponse,
                     weather: WeatherResponse?,
                     thresholdMmPerHour: Double,
                     horizonMinutes: Int) -> RainActivityPlan {
        let withinHorizon = rain.samples.filter { $0.minutesAhead <= horizonMinutes }
        let startsAt = withinHorizon.first { $0.mmPerHour >= thresholdMmPerHour }?.validAt
        let stopsAt: Date?
        if let startsAt {
            stopsAt = withinHorizon
                .first { $0.validAt > startsAt && $0.mmPerHour < thresholdMmPerHour }?
                .validAt
        } else {
            stopsAt = nil
        }

        let intensities = withinHorizon.prefix(24).map { min($0.mmPerHour, 50) }
        let condition = weather?.current.condition.rawValue ?? "unknown"
        let headline = makeHeadline(startsAt: startsAt, stopsAt: stopsAt)

        let state = RainActivityAttributes.ContentState(
            intensities: Array(intensities),
            startsAt: startsAt,
            stopsAt: stopsAt,
            analysisAt: rain.analysisAt,
            headline: headline,
            conditionRaw: condition
        )

        let willRain = startsAt != nil
        let action: Action
        if willRain {
            action = .start  // controller upgrades to .update if already running
        } else {
            action = .end    // controller no-ops if nothing is running
        }
        return RainActivityPlan(action: action, state: state)
    }

    private static func makeHeadline(startsAt: Date?, stopsAt: Date?) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        if let startsAt {
            let t = fmt.string(from: startsAt)
            if let stopsAt {
                return "Regen \(t)–\(fmt.string(from: stopsAt))"
            }
            return "Regen om \(t)"
        }
        return "Geen regen verwacht"
    }
}
