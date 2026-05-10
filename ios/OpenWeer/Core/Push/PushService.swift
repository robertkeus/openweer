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

    func handleRegistered(token: String) async {
        deviceToken = token
        log.debug("registered APNs token len=\(token.count)")
        // Backend registration is wired up in milestone 9 once
        // PushRegistration knows the user's last-known coords + language.
        await PushRegistration.shared.uploadIfReady(token: token)
    }

    func handleRegistrationFailure(_ error: Error) {
        log.error("APNs registration failed: \(error.localizedDescription)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
