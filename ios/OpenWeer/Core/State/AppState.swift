import Foundation
import CoreLocation
import SwiftUI
import WidgetKit

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

/// User-selectable forecast horizon. +2h is the radar-only nowcast horizon;
/// longer values bring in HARMONIE-AROME hourly forecast frames.
enum ForecastHorizon: Int, CaseIterable, Identifiable, Codable {
    case h2 = 2, h3 = 3, h6 = 6, h8 = 8, h12 = 12, h24 = 24
    var id: Int { rawValue }
    var hours: Int { rawValue }

    static let `default`: ForecastHorizon = .h2
}

@Observable
final class AppState {
    var theme: ThemePreference {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }
    var language: LanguagePreference {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }

    var coordinate: CLLocationCoordinate2D {
        didSet { mirrorLocationToAppGroup() }
    }
    var locationName: String {
        didSet { mirrorLocationToAppGroup() }
    }

    var frames: [Frame] = []
    var selectedFrameIndex: Int = 0
    var forecastHorizon: ForecastHorizon {
        didSet { UserDefaults.standard.set(forecastHorizon.rawValue, forKey: "forecastHorizon") }
    }

    var rain: RainResponse? {
        didSet {
            cacheSnapshot(.rain)
            onRainUpdated()
            WidgetCenter.shared.reloadTimelines(ofKind: "nl.openweer.widget.rain")
        }
    }
    var weather: WeatherResponse? {
        didSet {
            cacheSnapshot(.current)
            WidgetCenter.shared.reloadTimelines(ofKind: "nl.openweer.widget.current")
        }
    }
    var forecast: ForecastResponse? {
        didSet {
            cacheSnapshot(.forecast)
            WidgetCenter.shared.reloadTimelines(ofKind: "nl.openweer.widget.forecast")
        }
    }

    init() {
        let storedTheme = UserDefaults.standard.string(forKey: "theme").flatMap(ThemePreference.init(rawValue:))
        self.theme = storedTheme ?? .system

        let storedLang = UserDefaults.standard.string(forKey: "language").flatMap(LanguagePreference.init(rawValue:))
        self.language = storedLang ?? .nl

        let storedHorizon = ForecastHorizon(rawValue: UserDefaults.standard.integer(forKey: "forecastHorizon"))
        self.forecastHorizon = storedHorizon ?? .default

        let amsterdam = KnownLocations.all.first { $0.slug == "amsterdam" }!
        self.coordinate = amsterdam.coordinate
        self.locationName = amsterdam.name

        // Seed the app-group bridge so widgets have a coord on first launch
        // even before LocationService resolves.
        mirrorLocationToAppGroup()
    }

    private func mirrorLocationToAppGroup() {
        SharedLocation.save(coordinate: coordinate, name: locationName)
    }

    /// Writes the latest slice into the shared snapshot for the matching
    /// widget kind. The current-conditions widget pulls both weather + rain,
    /// so we keep its weather snapshot's rain field in sync too.
    private func cacheSnapshot(_ kind: SharedSnapshot.Kind) {
        let location = SharedLocation.load() ?? .amsterdamFallback
        let snap = SharedSnapshot(
            location: location,
            weather: kind == .current ? weather : nil,
            rain: (kind == .rain || kind == .current) ? rain : nil,
            forecast: kind == .forecast ? forecast : nil,
            cachedAt: Date()
        )
        SharedSnapshot.save(snap, as: kind)
    }

    private func onRainUpdated() {
        guard let rain else { return }
        Task { @MainActor in
            await RainLiveActivityController.shared.ensure(
                rain: rain,
                weather: weather,
                location: locationName
            )
        }
    }
}
