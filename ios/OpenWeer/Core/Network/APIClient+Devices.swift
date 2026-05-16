import Foundation

/// Device-registration + favorite-sync endpoints. Kept in a main-app-only
/// extension because they depend on `Favorite` / `LanguagePreference` types
/// the widget extension doesn't compile.
extension APIClient {
    /// Upsert this device with the backend. Returns the favorites currently
    /// known server-side so the client can reconcile on launch.
    func registerDevice(
        token: String,
        language: LanguagePreference,
        appVersion: String?
    ) async throws -> DeviceResponse {
        struct Body: Encodable {
            let token: String
            let platform: String
            let language: String
            let app_version: String?
        }
        let body = Body(
            token: token,
            platform: "ios",
            language: language.rawValue,
            app_version: appVersion
        )
        return try await postJSONInternal("/api/devices", body: body, as: DeviceResponse.self)
    }

    /// Replace the device's favorite set atomically.
    func putFavorites(
        token: String,
        favorites: [Favorite]
    ) async throws -> DeviceResponse {
        struct Body: Encodable {
            let favorites: [FavoriteWire]
        }
        let body = Body(favorites: favorites.map(FavoriteWire.init(from:)))
        return try await putJSONInternal(
            "/api/devices/\(token)/favorites",
            body: body,
            as: DeviceResponse.self
        )
    }

    func getDevice(token: String) async throws -> DeviceResponse {
        try await getInternal("/api/devices/\(token)", as: DeviceResponse.self)
    }

    func deleteDevice(token: String) async throws {
        try await deleteInternal("/api/devices/\(token)")
    }
}
