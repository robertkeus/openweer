import Foundation

/// Identifier and shared `UserDefaults` for the app + widget extension. The
/// matching value lives in both `OpenWeer.entitlements` and
/// `OpenWeerWidgets.entitlements` under `com.apple.security.application-groups`.
enum AppGroup {
    static let id = "group.nl.openweer.app"

    /// Shared `UserDefaults` for the app group. Falls back to `.standard`
    /// only if the suite cannot be created — that means the entitlement is
    /// misconfigured, so we log loudly in DEBUG and degrade rather than crash.
    static var userDefaults: UserDefaults {
        if let suite = UserDefaults(suiteName: id) {
            return suite
        }
        #if DEBUG
        assertionFailure("App Group \(id) is not configured; falling back to .standard")
        #endif
        return .standard
    }
}
