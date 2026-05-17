import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = PushService.shared
        // BGTaskScheduler.register must run before app launch finishes.
        WidgetBackgroundRefresh.shared.register()
        // Ask the system for our first refresh slot — it picks the real time.
        WidgetBackgroundRefresh.shared.schedule()
        // If the user previously granted notification permission, refresh
        // the device token on every launch. APNs may rotate the token, and
        // this is how we pick up the new one.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Re-arm the task whenever the user puts the app away — gives iOS
        // the most relevant signal for picking a run time.
        WidgetBackgroundRefresh.shared.schedule()
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await PushService.shared.handleRegistered(token: token) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushService.shared.handleRegistrationFailure(error)
    }
}
