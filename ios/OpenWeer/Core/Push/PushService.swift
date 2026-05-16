import Foundation
import UIKit
import UserNotifications
import os

@MainActor
final class PushService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushService()

    private let log = Logger(subsystem: "nl.openweer.app", category: "push")
    private(set) var deviceToken: String?

    private override init() { super.init() }

    func requestAuthorizationAndRegister() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            log.error("notification authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Called from `AppDelegate` once APNs hands us a token. Registers the
    /// device with the backend and triggers an immediate favorites sync so
    /// the server has the latest set the moment a token exists.
    func handleRegistered(token: String) async {
        deviceToken = token
        log.debug("registered APNs token len=\(token.count)")
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        do {
            _ = try await APIClient.shared.registerDevice(
                token: token,
                language: AppStateLanguageProvider.current(),
                appVersion: appVersion
            )
            await FavoritesSync.shared.syncNow()
        } catch {
            log.error("device registration failed: \(error.localizedDescription)")
        }
    }

    func handleRegistrationFailure(_ error: Error) {
        log.error("APNs registration failed: \(error.localizedDescription)")
    }

    /// Current iOS notification authorization status for the app.
    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    enum EnableResult {
        /// Permission granted and `registerForRemoteNotifications` was kicked off.
        case enabled
        /// User declined the system prompt this run.
        case denied
        /// Previously denied — caller must guide the user to iOS Settings.
        case needsSystemSettings
    }

    /// Turning the in-app toggle ON. Handles the three states (not yet asked,
    /// granted, previously denied) so the UI can show the right affordance.
    func enableFromSettings() async -> EnableResult {
        let status = await currentAuthorizationStatus()
        switch status {
        case .notDetermined:
            let granted = await requestAuthorizationAndRegister()
            return granted ? .enabled : .denied
        case .denied:
            return .needsSystemSettings
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
            return .enabled
        @unknown default:
            return .denied
        }
    }

    /// Called when the user denies notifications or signs out. Best-effort
    /// — failure is non-fatal because the next push attempt will surface a
    /// terminal token and the backend will drop the row anyway.
    func unsubscribe() async {
        guard let token = deviceToken else { return }
        deviceToken = nil
        do {
            try await APIClient.shared.deleteDevice(token: token)
        } catch {
            log.error("unsubscribe failed: \(error.localizedDescription)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// Tiny shim so PushService doesn't need to read AppState directly — keeps
/// the actor/MainActor boundary clean and lets tests inject a different value.
enum AppStateLanguageProvider {
    static func current() -> LanguagePreference {
        if let raw = UserDefaults.standard.string(forKey: "language"),
           let lang = LanguagePreference(rawValue: raw) {
            return lang
        }
        return .systemDefault
    }
}
