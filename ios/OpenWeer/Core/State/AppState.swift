import Foundation
import CoreLocation
import SwiftUI

enum ThemePreference: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var colorScheme: SwiftUI.ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum LanguagePreference: String, CaseIterable, Identifiable {
    case nl, en
    var id: String { rawValue }
}

@Observable
final class AppState {
    var theme: ThemePreference {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }
    var language: LanguagePreference {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }

    var coordinate: CLLocationCoordinate2D
    var locationName: String

    var frames: [Frame] = []
    var selectedFrameIndex: Int = 0

    var rain: RainResponse?
    var weather: WeatherResponse?
    var forecast: ForecastResponse?

    init() {
        let storedTheme = UserDefaults.standard.string(forKey: "theme").flatMap(ThemePreference.init(rawValue:))
        self.theme = storedTheme ?? .system

        let storedLang = UserDefaults.standard.string(forKey: "language").flatMap(LanguagePreference.init(rawValue:))
        self.language = storedLang ?? .nl

        let amsterdam = KnownLocations.all.first { $0.slug == "amsterdam" }!
        self.coordinate = amsterdam.coordinate
        self.locationName = amsterdam.name
    }
}
