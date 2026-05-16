import Foundation
import CoreLocation

/// Last accepted location, written by the main app and read by the widget
/// extension. We persist a single JSON blob under `AppGroup.userDefaults` so
/// the widget never has to call `CLLocationManager` itself.
struct SharedLocation: Codable, Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let name: String
    let updatedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension SharedLocation {
    private static let key = "sharedLocation.v1"

    static func load(from defaults: UserDefaults = AppGroup.userDefaults) -> SharedLocation? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedLocation.self, from: data)
    }

    static func save(_ value: SharedLocation, to defaults: UserDefaults = AppGroup.userDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    /// Convenience for callers that already have a `CLLocationCoordinate2D`.
    static func save(coordinate: CLLocationCoordinate2D,
                     name: String,
                     to defaults: UserDefaults = AppGroup.userDefaults) {
        save(.init(latitude: coordinate.latitude,
                   longitude: coordinate.longitude,
                   name: name,
                   updatedAt: Date()), to: defaults)
    }

    /// Fallback when the user hasn't allowed location yet. Matches the app's
    /// own first-run fallback in `AppState`.
    static var amsterdamFallback: SharedLocation {
        let amsterdam = KnownLocations.all.first { $0.slug == "amsterdam" }!
        return .init(latitude: amsterdam.lat,
                     longitude: amsterdam.lon,
                     name: amsterdam.name,
                     updatedAt: .distantPast)
    }
}
