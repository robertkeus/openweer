import Foundation
import CoreLocation

/// Lead-time options for rain alerts. Backed by `LeadTime` on the server
/// (15/30/60 min); rejecting other values means the API can't drift out
/// of sync with the iOS UI without a compile error here too.
enum FavoriteLeadTime: Int, Codable, CaseIterable, Identifiable, Sendable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60

    var id: Int { rawValue }
    var minutes: Int { rawValue }
}

/// Rain-intensity threshold that triggers a push.
/// Mirrors `Intensity` on the server. Order is severity-ascending.
enum FavoriteIntensity: String, Codable, CaseIterable, Identifiable, Sendable {
    case light, moderate, heavy

    var id: String { rawValue }
}

/// Local representation of an alert preference, encoded as the server's
/// `alert_prefs` object inside a favorite.
struct FavoriteAlertPrefs: Codable, Hashable, Sendable {
    var leadTime: FavoriteLeadTime
    var threshold: FavoriteIntensity
    /// Quiet hours in *local* device time, [start, end) on a 24-hour clock.
    /// Both must be set or both nil — the editor enforces this invariant.
    var quietHoursStart: Int?
    var quietHoursEnd: Int?

    static let `default` = FavoriteAlertPrefs(
        leadTime: .thirty,
        threshold: .moderate,
        quietHoursStart: nil,
        quietHoursEnd: nil
    )

    enum CodingKeys: String, CodingKey {
        case leadTime = "lead_time_min"
        case threshold
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
    }
}

/// One favorite location with its alert prefs. `id` is a client-side
/// UUID; the server assigns its own `favorite_id` when synced.
struct Favorite: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var label: String
    var latitude: Double
    var longitude: Double
    var alertPrefs: FavoriteAlertPrefs

    init(
        id: UUID = UUID(),
        label: String,
        coordinate: CLLocationCoordinate2D,
        alertPrefs: FavoriteAlertPrefs = .default
    ) {
        self.id = id
        self.label = label
        // Persist coords rounded to two decimals: matches the backend's A09
        // storage policy and avoids drift when the client and server round
        // independently.
        self.latitude = (coordinate.latitude * 100).rounded() / 100
        self.longitude = (coordinate.longitude * 100).rounded() / 100
        self.alertPrefs = alertPrefs
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
