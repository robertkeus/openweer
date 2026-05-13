import SwiftUI

/// Maps WMO weather codes (used by Open-Meteo) and KNMI condition kinds to SF Symbols.
enum WeatherIcon {
    /// WMO weather codes: https://open-meteo.com/en/docs#weathervariables
    static func symbol(forWmoCode code: Int?) -> String {
        guard let code else { return "questionmark.circle" }
        switch code {
        case 0:        return "sun.max.fill"
        case 1:        return "sun.haze.fill"
        case 2:        return "cloud.sun.fill"
        case 3:        return "cloud.fill"
        case 45, 48:   return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 71, 73, 75, 77:     return "cloud.snow.fill"
        case 80, 81, 82:         return "cloud.heavyrain.fill"
        case 85, 86:             return "cloud.snow.fill"
        case 95:                 return "cloud.bolt.rain.fill"
        case 96, 99:             return "cloud.bolt.fill"
        default:                 return "cloud.fill"
        }
    }

    static func symbol(forCondition kind: ConditionKind) -> String {
        switch kind {
        case .clear:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .fog:          return "cloud.fog.fill"
        case .drizzle:      return "cloud.drizzle.fill"
        case .rain:         return "cloud.rain.fill"
        case .thunder:      return "cloud.bolt.rain.fill"
        case .snow:         return "cloud.snow.fill"
        case .unknown:      return "questionmark.circle"
        }
    }

    static func tint(forCondition kind: ConditionKind) -> Color {
        switch kind {
        case .clear, .partlyCloudy: return .owSun
        default:                    return .owAccent
        }
    }
}
