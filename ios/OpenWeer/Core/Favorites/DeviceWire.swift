import Foundation

/// JSON-encoded shape of a favorite as the backend expects it.
/// Separated from the SwiftUI-facing `Favorite` so the API contract can
/// evolve independently from the app's in-memory representation.
struct FavoriteWire: Codable, Sendable {
    let label: String
    let latitude: Double
    let longitude: Double
    let alert_prefs: AlertPrefsWire

    init(from favorite: Favorite) {
        self.label = favorite.label
        self.latitude = favorite.latitude
        self.longitude = favorite.longitude
        self.alert_prefs = AlertPrefsWire(
            lead_time_min: favorite.alertPrefs.leadTime.rawValue,
            threshold: favorite.alertPrefs.threshold.rawValue,
            quiet_hours_start: favorite.alertPrefs.quietHoursStart,
            quiet_hours_end: favorite.alertPrefs.quietHoursEnd
        )
    }
}

struct AlertPrefsWire: Codable, Sendable {
    let lead_time_min: Int
    let threshold: String
    let quiet_hours_start: Int?
    let quiet_hours_end: Int?
}

/// Server-assigned identifier + persisted alert prefs.
/// We mostly trust the local store but decode this so registration roundtrips work.
struct DeviceFavoriteWire: Codable, Sendable {
    let favorite_id: Int
    let label: String
    let latitude: Double
    let longitude: Double
    let alert_prefs: AlertPrefsWire
    let created_at: Date
}

struct DeviceResponse: Codable, Sendable {
    let device_id: String
    let favorites: [DeviceFavoriteWire]
}
