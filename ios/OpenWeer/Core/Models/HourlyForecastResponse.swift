import Foundation

struct HourlySlot: Codable, Hashable, Identifiable, Sendable {
    let time: Date
    let weatherCode: Int?
    let temperatureC: Double?
    let apparentTemperatureC: Double?
    let precipitationMm: Double?
    let precipitationProbabilityPct: Int?
    let windSpeedKph: Double?
    let windDirectionDeg: Int?
    let windGustsKph: Double?
    let relativeHumidityPct: Int?
    let cloudCoverPct: Int?
    let uvIndex: Double?
    let isDay: Bool?
    let source: String?

    var id: Date { time }

    enum CodingKeys: String, CodingKey {
        case time
        case weatherCode = "weather_code"
        case temperatureC = "temperature_c"
        case apparentTemperatureC = "apparent_temperature_c"
        case precipitationMm = "precipitation_mm"
        case precipitationProbabilityPct = "precipitation_probability_pct"
        case windSpeedKph = "wind_speed_kph"
        case windDirectionDeg = "wind_direction_deg"
        case windGustsKph = "wind_gusts_kph"
        case relativeHumidityPct = "relative_humidity_pct"
        case cloudCoverPct = "cloud_cover_pct"
        case uvIndex = "uv_index"
        case isDay = "is_day"
        case source
    }
}

struct HourlyForecastResponse: Codable, Hashable, Sendable {
    let lat: Double
    let lon: Double
    let source: String
    let timezone: String
    let hours: [HourlySlot]

    /// Slots whose `time` falls on the given `yyyy-MM-dd` in Europe/Amsterdam.
    func slots(forDate isoDate: String) -> [HourlySlot] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return hours.filter { formatter.string(from: $0.time) == isoDate }
    }
}
