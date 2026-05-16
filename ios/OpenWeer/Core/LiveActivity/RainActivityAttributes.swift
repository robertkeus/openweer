import Foundation
import ActivityKit

/// Live Activity payload for the 2-hour rain nowcast. Members must stay
/// `Codable` and lightweight: ActivityKit caps each ContentState at 4 KB.
struct RainActivityAttributes: ActivityAttributes, Sendable {
    typealias ContentState = State

    let locationName: String

    struct State: Codable, Hashable, Sendable {
        /// Up to 24 normalized mm/h samples covering the next 2 hours
        /// (5-min cadence). Clamped to <= 50 to keep the encoding small.
        let intensities: [Double]
        /// First moment within the horizon where mm/h crosses the rain
        /// threshold, or `nil` if it stays dry.
        let startsAt: Date?
        /// First moment after `startsAt` where it drops back below the
        /// threshold, or `nil` if rain continues past the horizon.
        let stopsAt: Date?
        let analysisAt: Date
        let headline: String
        let conditionRaw: String
    }
}
