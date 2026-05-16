import Foundation

/// Pure helpers for deciding the next reload moment. Kept side-effect-free
/// so it can be unit-tested without WidgetKit.
enum WidgetRefreshPolicy {
    /// Rain analysis is updated by KNMI every ~5 min; we give ourselves a
    /// little headroom.
    static let rainCadence: TimeInterval = 10 * 60
    /// Surface obs come from the KNMI hourly cycle but the API publishes
    /// 10-min station data; 20 min is plenty for a glanceable temp.
    static let currentCadence: TimeInterval = 20 * 60
    /// Daily forecast only changes on the model run boundary.
    static let forecastCadence: TimeInterval = 60 * 60

    static func nextReload(now: Date, kind: SharedSnapshot.Kind) -> Date {
        switch kind {
        case .rain:     return now.addingTimeInterval(rainCadence)
        case .current:  return now.addingTimeInterval(currentCadence)
        case .forecast: return now.addingTimeInterval(forecastCadence)
        }
    }

    /// How many entries to fan one fetched payload into, and how far apart
    /// they sit on the timeline. Multiple entries with progressing dates let
    /// countdown labels tick down between network polls.
    static func fanOut(kind: SharedSnapshot.Kind) -> (count: Int, stride: TimeInterval) {
        switch kind {
        case .rain:     return (6, 90)         // every 90 s, 9 min total
        case .current:  return (4, 5 * 60)     // every 5 min, 20 min total
        case .forecast: return (1, 0)
        }
    }
}
