import Foundation

enum ConditionKind: String, Codable, Sendable {
    case clear
    case partlyCloudy = "partly-cloudy"
    case cloudy
    case fog
    case drizzle
    case rain
    case thunder
    case snow
    case unknown
}

struct WeatherStation: Codable, Hashable, Sendable {
    let name: String
    let id: String
    let lat: Double
    let lon: Double
    let distanceKm: Double

    enum CodingKeys: String, CodingKey {
        case name, id, lat, lon
        case distanceKm = "distance_km"
    }
}

struct CurrentWeather: Codable, Hashable, Sendable {
    let observedAt: Date
    let temperatureC: Double?
    let feelsLikeC: Double?
    let condition: ConditionKind
    let conditionLabel: String
    let windSpeedMps: Double?
    let windSpeedBft: Int?
    let windDirectionDeg: Double?
    let windDirectionCompass: String?
    let humidityPct: Double?
    let pressureHpa: Double?
    let rainfall1hMm: Double?
    let rainfall24hMm: Double?
    let cloudCoverOctas: Double?
    let visibilityM: Double?

    enum CodingKeys: String, CodingKey {
        case observedAt = "observed_at"
        case temperatureC = "temperature_c"
        case feelsLikeC = "feels_like_c"
        case condition
        case conditionLabel = "condition_label"
        case windSpeedMps = "wind_speed_mps"
        case windSpeedBft = "wind_speed_bft"
        case windDirectionDeg = "wind_direction_deg"
        case windDirectionCompass = "wind_direction_compass"
        case humidityPct = "humidity_pct"
        case pressureHpa = "pressure_hpa"
        case rainfall1hMm = "rainfall_1h_mm"
        case rainfall24hMm = "rainfall_24h_mm"
        case cloudCoverOctas = "cloud_cover_octas"
        case visibilityM = "visibility_m"
    }
}

struct WeatherResponse: Codable, Hashable, Sendable {
    let station: WeatherStation
    let current: CurrentWeather
}
