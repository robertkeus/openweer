import Foundation
import CoreLocation

/// Asks CoreLocation for the device's current location from inside the widget
/// extension. We don't rely on the App Group bridge anymore because that
/// silently fails on free Apple IDs — the entitlement is stripped from the
/// provisioning profile and writes never reach the widget process.
///
/// Widgets can't prompt for permission. They inherit the containing app's
/// authorization status; if the user already granted "When in Use" to the
/// main app, `requestLocation()` here will succeed.
final class WidgetLocationProvider: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    /// Resolve a coordinate within `timeout` seconds. Returns nil on
    /// timeout, permission denial, or any CoreLocation error — callers
    /// should fall back to a default location.
    func resolve(timeout: TimeInterval = 2.0) async -> CLLocationCoordinate2D? {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer

        // First try the cached location — instant, no prompt, no network.
        if let cached = manager.location?.coordinate,
           NLBoundingBox.contains(cached) {
            return cached
        }

        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return nil
        }

        return await withTaskGroup(of: CLLocationCoordinate2D?.self) { group in
            group.addTask { [weak self] in
                await withCheckedContinuation { (cont: CheckedContinuation<CLLocationCoordinate2D?, Never>) in
                    self?.continuation = cont
                    self?.manager.requestLocation()
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        let coord = locations.last?.coordinate
        let valid = coord.map(NLBoundingBox.contains) ?? false
        continuation?.resume(returning: valid ? coord : nil)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}
