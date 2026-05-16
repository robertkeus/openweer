import Foundation
import WidgetKit

/// Single payload type used by every OpenWeer widget kind. Individual widgets
/// look at only the slices they need; the rest stay `nil`.
struct WidgetEntry: TimelineEntry {
    let date: Date
    let location: SharedLocation
    let weather: WeatherResponse?
    let rain: RainResponse?
    let forecast: ForecastResponse?
    /// Composited rain-radar PNG for the RainMap widget. Carried as `Data`
    /// because `UIImage` isn't `Sendable` and we want the cache path to
    /// round-trip through JSON cleanly.
    let mapImageData: Data?
    /// Set when the entry came from the offline cache instead of a fresh
    /// network call. Widgets can dim or mark the timestamp.
    let isStale: Bool
}

extension WidgetEntry {
    static func placeholder(now: Date = Date()) -> WidgetEntry {
        WidgetEntry(date: now,
                    location: .amsterdamFallback,
                    weather: nil,
                    rain: nil,
                    forecast: nil,
                    mapImageData: nil,
                    isStale: false)
    }
}
