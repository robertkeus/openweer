import Foundation
import WidgetKit
import os

private let log = Logger(subsystem: "nl.openweer.app.widgets", category: "loader")

/// Resolves the location, fans out to the API, and writes an offline cache.
/// Each widget kind only fetches what it needs.
enum WidgetDataLoader {

    /// Hard cap on a single timeline build so WidgetKit's ~5 s budget is
    /// never blown — better to render fallback data than to hang in the
    /// auto-redacted placeholder.
    private static let timelineDeadline: TimeInterval = 4.0

    static func placeholder() -> WidgetEntry { .placeholder() }

    /// Snapshot used for Smart Stack previews and gallery thumbnails. We
    /// return the cached entry immediately when available so the preview
    /// reflects real data, falling back to a placeholder otherwise.
    static func snapshot(for kind: SharedSnapshot.Kind) -> WidgetEntry {
        if let cached = SharedSnapshot.load(kind) {
            return WidgetEntry(date: cached.cachedAt,
                               location: cached.location,
                               weather: cached.weather,
                               rain: cached.rain,
                               forecast: cached.forecast,
                               isStale: false)
        }
        return .placeholder()
    }

    /// Build a multi-entry timeline so countdown labels stay live between
    /// network reloads. Same data, ticking timestamps — iOS picks the right
    /// entry to render based on `entry.date`.
    static func timeline(for kind: SharedSnapshot.Kind) async -> Timeline<WidgetEntry> {
        let now = Date()
        let location = await resolveLocation()
        log.info("timeline kind=\(kind.rawValue) loc=\(location.name) (\(location.latitude),\(location.longitude))")

        do {
            let base = try await withTimeout(timelineDeadline) {
                try await fetchFresh(kind: kind, location: location, now: now)
            }
            persist(entry: base, as: kind)
            log.info("timeline kind=\(kind.rawValue) ok hasWeather=\(base.weather != nil) hasRain=\(base.rain != nil) hasForecast=\(base.forecast != nil)")
            return Timeline(entries: fanOut(base, kind: kind, now: now),
                            policy: .after(WidgetRefreshPolicy.nextReload(now: now, kind: kind)))
        } catch {
            log.error("timeline kind=\(kind.rawValue) fetch failed: \(String(describing: error))")
            // Network blip / timeout: serve whatever we cached last so the
            // widget keeps showing useful data instead of going blank.
            let fallback = cachedFallback(kind: kind, location: location, now: now)
            return Timeline(entries: fanOut(fallback, kind: kind, now: now),
                            policy: .after(now.addingTimeInterval(5 * 60)))
        }
    }

    // MARK: - Location

    /// Prefer the App-Group-shared location written by the main app. When
    /// that is unavailable (free Apple IDs, fresh install before the app
    /// has written anything), ask CoreLocation directly. Final fallback is
    /// Amsterdam so we always have a coord inside the NL bbox.
    private static func resolveLocation() async -> SharedLocation {
        if let shared = SharedLocation.load() {
            return shared
        }
        if let coord = await WidgetLocationProvider().resolve() {
            return SharedLocation(latitude: coord.latitude,
                                  longitude: coord.longitude,
                                  name: "Mijn locatie",
                                  updatedAt: Date())
        }
        return .amsterdamFallback
    }

    // MARK: - Entries

    private static func fanOut(_ base: WidgetEntry,
                               kind: SharedSnapshot.Kind,
                               now: Date) -> [WidgetEntry] {
        let plan = WidgetRefreshPolicy.fanOut(kind: kind)
        return (0..<plan.count).map { i in
            WidgetEntry(date: now.addingTimeInterval(TimeInterval(i) * plan.stride),
                        location: base.location,
                        weather: base.weather,
                        rain: base.rain,
                        forecast: base.forecast,
                        isStale: base.isStale)
        }
    }

    // MARK: - Fetch

    private static func fetchFresh(kind: SharedSnapshot.Kind,
                                   location: SharedLocation,
                                   now: Date) async throws -> WidgetEntry {
        let coord = location.coordinate
        switch kind {
        case .current:
            async let weather = APIClient.shared.weather(at: coord)
            async let rain = APIClient.shared.rain(at: coord)
            let (w, r) = try await (weather, rain)
            return WidgetEntry(date: now, location: location,
                               weather: w, rain: r, forecast: nil, isStale: false)
        case .rain:
            let r = try await APIClient.shared.rain(at: coord)
            return WidgetEntry(date: now, location: location,
                               weather: nil, rain: r, forecast: nil, isStale: false)
        case .forecast:
            let f = try await APIClient.shared.forecast(at: coord)
            return WidgetEntry(date: now, location: location,
                               weather: nil, rain: nil, forecast: f, isStale: false)
        }
    }

    private static func persist(entry: WidgetEntry, as kind: SharedSnapshot.Kind) {
        let snap = SharedSnapshot(location: entry.location,
                                  weather: entry.weather,
                                  rain: entry.rain,
                                  forecast: entry.forecast,
                                  cachedAt: entry.date)
        SharedSnapshot.save(snap, as: kind)
    }

    private static func cachedFallback(kind: SharedSnapshot.Kind,
                                       location: SharedLocation,
                                       now: Date) -> WidgetEntry {
        if let cached = SharedSnapshot.load(kind) {
            return WidgetEntry(date: cached.cachedAt,
                               location: cached.location,
                               weather: cached.weather,
                               rain: cached.rain,
                               forecast: cached.forecast,
                               isStale: true)
        }
        return WidgetEntry(date: now, location: location,
                           weather: nil, rain: nil, forecast: nil, isStale: true)
    }

    // MARK: - Timeout

    /// Races `op` against a sleep. Throws `WidgetLoaderError.timedOut` if
    /// `op` doesn't finish first. Cancellation of `op` is best-effort.
    private static func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        _ op: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await op() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw WidgetLoaderError.timedOut
            }
            let value = try await group.next()!
            group.cancelAll()
            return value
        }
    }
}

enum WidgetLoaderError: Error { case timedOut }
