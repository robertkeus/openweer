import Foundation
import CoreLocation

/// Hourly forecast endpoint. Kept in a main-app-only extension because
/// `HourlyForecastResponse` isn't compiled into the widget target.
extension APIClient {
    /// Fetches the 8-day hourly forecast for the given coordinate.
    /// Backed by `/api/forecast/{lat}/{lon}/hourly` — HARMONIE-AROME for the
    /// first ~48 hours, ECMWF IFS beyond. Per-slot `source` indicates which.
    func hourlyForecast(at coord: CLLocationCoordinate2D) async throws -> HourlyForecastResponse {
        guard NLBoundingBox.contains(coord) else {
            throw APIError.outOfBounds(lat: coord.latitude, lon: coord.longitude)
        }
        let lat = String(format: "%.4f", coord.latitude)
        let lon = String(format: "%.4f", coord.longitude)
        return try await getInternal(
            "/api/forecast/\(lat)/\(lon)/hourly",
            as: HourlyForecastResponse.self
        )
    }
}
