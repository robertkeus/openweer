import Foundation

/// Last successful widget payload, cached in the App Group so a flaky network
/// doesn't blank the widget. Each widget kind caches under its own key.
struct SharedSnapshot: Codable, Sendable {
    let location: SharedLocation
    let weather: WeatherResponse?
    let rain: RainResponse?
    let forecast: ForecastResponse?
    let cachedAt: Date
}

extension SharedSnapshot {
    enum Kind: String {
        case current, rain, forecast
        var key: String { "sharedSnapshot.v1.\(rawValue)" }
    }

    static func load(_ kind: Kind,
                     from defaults: UserDefaults = AppGroup.userDefaults) -> SharedSnapshot? {
        guard let data = defaults.data(forKey: kind.key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SharedSnapshot.self, from: data)
    }

    static func save(_ snapshot: SharedSnapshot,
                     as kind: Kind,
                     to defaults: UserDefaults = AppGroup.userDefaults) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: kind.key)
    }
}
