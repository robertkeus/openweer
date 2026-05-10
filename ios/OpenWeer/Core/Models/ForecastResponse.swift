import Foundation

struct DailyForecast: Codable, Hashable, Identifiable, Sendable {
    let date: String
    let weatherCode: Int?
    let temperatureMaxC: Double?
    let temperatureMinC: Double?
    let precipitationSumMm: Double?
    let precipitationProbabilityPct: Int?
    let windMaxKph: Double?
    let windDirectionDeg: Int?
    let sunrise: String?
    let sunset: String?
    let source: String?

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case weatherCode = "weather_code"
        case temperatureMaxC = "temperature_max_c"
        case temperatureMinC = "temperature_min_c"
        case precipitationSumMm = "precipitation_sum_mm"
        case precipitationProbabilityPct = "precipitation_probability_pct"
        case windMaxKph = "wind_max_kph"
        case windDirectionDeg = "wind_direction_deg"
        case sunrise, sunset, source
    }
}

struct ForecastResponse: Codable, Hashable, Sendable {
    let lat: Double
    let lon: Double
    let source: String
    let days: [DailyForecast]
}
