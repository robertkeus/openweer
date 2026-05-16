import Foundation
import CoreLocation
import Combine
import os

/// Wraps CLLocationManager so the rest of the app can observe authorization +
/// last known coordinate without dealing with delegate callbacks.
@MainActor
@Observable
final class LocationService: NSObject {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private let log = Logger(subsystem: "nl.openweer.app", category: "location")
    private let geocoder = CLGeocoder()

    /// Current authorization status, kept in sync with the system.
    var authorizationStatus: CLAuthorizationStatus

    /// The last accepted coordinate (validated against the NL bbox).
    var lastCoordinate: CLLocationCoordinate2D?

    /// Reverse-geocoded human-readable name for `lastCoordinate`.
    var lastPlaceName: String?

    /// Set to true while a one-shot fetch is in flight.
    var isResolving: Bool = false

    /// True if a permission prompt has been issued during this session.
    private var hasPromptedThisSession = false

    private var pendingContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    private override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
    }

    /// Request When-In-Use permission. Safe to call multiple times: only the
    /// first call surfaces the system dialog.
    func requestPermission() {
        guard authorizationStatus == .notDetermined else { return }
        hasPromptedThisSession = true
        manager.requestWhenInUseAuthorization()
    }

    /// Asks for the current location once. Returns the coordinate if the user
    /// is authorized and inside NL, otherwise nil. Callers can fall back to a
    /// preset.
    @discardableResult
    func resolveCurrentLocation() async -> CLLocationCoordinate2D? {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            return nil
        }
        if isResolving {
            // already in flight; just wait until it settles
            return await withCheckedContinuation { cont in
                pendingContinuation = cont
            }
        }
        isResolving = true
        return await withCheckedContinuation { cont in
            pendingContinuation = cont
            manager.requestLocation()
        }
    }

    /// Reverse-geocode an arbitrary coordinate. Used by the pan-to-set
    /// flow; does not touch `lastCoordinate` / `lastPlaceName` (those are
    /// reserved for the GPS path). Returns nil if the geocoder yields
    /// nothing usable — callers can fall back to a coordinate label.
    func resolvePlaceName(for coord: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let p = placemarks.first else { return nil }
            return p.locality
                ?? p.subAdministrativeArea
                ?? p.administrativeArea
                ?? p.country
        } catch {
            log.error("reverse geocode (pan) failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let p = placemarks.first {
                let name = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? "Mijn locatie"
                lastPlaceName = name
            }
        } catch {
            log.error("reverse geocode failed: \(error.localizedDescription)")
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = newStatus
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                self.manager.requestLocation()
                self.isResolving = true
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let coord = loc.coordinate
        let isValid = NLBoundingBox.contains(coord)
        Task { @MainActor in
            if isValid {
                self.lastCoordinate = coord
                self.log.debug("got coord \(coord.latitude),\(coord.longitude)")
                await self.reverseGeocode(coord)
                SharedLocation.save(coordinate: coord,
                                    name: self.lastPlaceName ?? "Mijn locatie")
                self.pendingContinuation?.resume(returning: coord)
            } else {
                self.log.info("coord outside NL bbox; ignored")
                self.pendingContinuation?.resume(returning: nil)
            }
            self.pendingContinuation = nil
            self.isResolving = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.log.error("locationManager error: \(error.localizedDescription)")
            self.pendingContinuation?.resume(returning: nil)
            self.pendingContinuation = nil
            self.isResolving = false
        }
    }
}
