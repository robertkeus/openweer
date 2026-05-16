import Foundation

/// Last successful widget payload, cached in the App Group so a flaky network
/// doesn't blank the widget. Each widget kind caches under its own key.
struct SharedSnapshot: Codable, Sendable {
    let location: SharedLocation
    let weather: WeatherResponse?
    let rain: RainResponse?
    let forecast: ForecastResponse?
    /// Optional composited radar PNG used by the rain-map widget.
    let mapImageData: Data?
    let cachedAt: Date

    init(location: SharedLocation,
         weather: WeatherResponse? = nil,
         rain: RainResponse? = nil,
         forecast: ForecastResponse? = nil,
         mapImageData: Data? = nil,
         cachedAt: Date) {
        self.location = location
        self.weather = weather
        self.rain = rain
        self.forecast = forecast
        self.mapImageData = mapImageData
        self.cachedAt = cachedAt
    }
}

extension SharedSnapshot {
    enum Kind: String {
        case current, rain, forecast, map
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
