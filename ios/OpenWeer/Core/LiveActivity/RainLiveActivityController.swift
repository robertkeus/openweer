import Foundation
import ActivityKit
import os

/// Manages the lifecycle of the rain Live Activity. The main app calls
/// `ensure(rain:weather:location:)` after every successful rain fetch; this
/// type decides whether to start, update, or end the activity.
@MainActor
final class RainLiveActivityController {
    static let shared = RainLiveActivityController()

    private let log = Logger(subsystem: "nl.openweer.app", category: "liveactivity")
    private var current: Activity<RainActivityAttributes>?

    /// mm/h threshold above which we consider "it's raining".
    private let rainThreshold: Double = 0.1
    /// Horizon we communicate to users (matches the nowcast endpoint).
    private let horizonMinutes: Int = 120

    private init() {
        // Re-attach to any activity already running from a previous launch.
        current = Activity<RainActivityAttributes>.activities.first
    }

    /// Public entry point. Idempotent — safe to call after every rain poll.
    func ensure(rain: RainResponse,
                weather: WeatherResponse?,
                location: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.debug("activities disabled by user")
            return
        }

        let plan = RainActivityPlan.from(rain: rain,
                                         weather: weather,
                                         thresholdMmPerHour: rainThreshold,
                                         horizonMinutes: horizonMinutes)

        switch plan.action {
        case .start:
            await start(plan: plan, location: location)
        case .update:
            await update(plan: plan)
        case .end:
            await end()
        case .noop:
            break
        }
    }

    private func start(plan: RainActivityPlan, location: String) async {
        guard current == nil else { return await update(plan: plan) }
        let attributes = RainActivityAttributes(locationName: location)
        let content = ActivityContent(state: plan.state,
                                      staleDate: Date().addingTimeInterval(15 * 60))
        do {
            current = try Activity.request(attributes: attributes, content: content)
            log.info("started rain live activity")
        } catch {
            log.error("could not start activity: \(String(describing: error))")
        }
    }

    private func update(plan: RainActivityPlan) async {
        guard let activity = current else { return }
        let content = ActivityContent(state: plan.state,
                                      staleDate: Date().addingTimeInterval(15 * 60))
        await activity.update(content)
    }

    private func end() async {
        guard let activity = current else { return }
        let dismissal: ActivityUIDismissalPolicy = .after(Date().addingTimeInterval(5 * 60))
        await activity.end(nil, dismissalPolicy: dismissal)
        current = nil
        log.info("ended rain live activity")
    }
}
