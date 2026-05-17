import Foundation
import BackgroundTasks
import WidgetKit
import CoreLocation
import os

/// Keeps the widgets fresh while the app is backgrounded or terminated.
/// WidgetKit's own `.after(_:)` policy is throttled aggressively by iOS;
/// scheduling a `BGAppRefreshTask` is the way Apple expects us to push
/// data updates outside the app's lifetime.
@MainActor
final class WidgetBackgroundRefresh {
    static let shared = WidgetBackgroundRefresh()
    static let taskIdentifier = "nl.openweer.app.refresh"

    private let log = Logger(subsystem: "nl.openweer.app", category: "background")
    /// Lower bound iOS uses — we request 15 minutes, the system decides when.
    private let earliestInterval: TimeInterval = 15 * 60

    private init() {}

    /// Registers the task with the system. Must run synchronously before the
    /// app finishes launching.
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier,
                                        using: nil) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                await self?.handle(task: task)
            }
        }
    }

    /// Asks the system to run the task again. Call after every successful
    /// refresh — iOS will pick the actual run time based on usage patterns.
    func schedule(after interval: TimeInterval? = nil) {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(interval ?? earliestInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
            log.info("scheduled BGTask earliest=\(request.earliestBeginDate?.description ?? "nil")")
        } catch {
            log.error("schedule BGTask failed: \(String(describing: error))")
        }
    }

    // MARK: - Handler

    private func handle(task: BGAppRefreshTask) async {
        log.info("BGTask fired")
        // Always reschedule first so we keep ticking even if this run fails.
        schedule()

        let work = Task { @MainActor in
            await self.refreshOnce()
        }
        task.expirationHandler = { work.cancel() }
        await work.value
        task.setTaskCompleted(success: true)
        log.info("BGTask completed")
    }

    /// One refresh pass: prefer the App-Group coord, fall back to
    /// CLLocationManager's cached fix. Fetches rain (cheap, the most
    /// time-sensitive widget) and asks WidgetKit to reload everything.
    private func refreshOnce() async {
        let coord = await resolveCoordinate()
        guard let coord else {
            log.info("BGTask skip: no location available")
            return
        }
        do {
            let rain = try await APIClient.shared.rain(at: coord)
            cache(rain: rain)
            log.info("BGTask refreshed rain @ \(coord.latitude),\(coord.longitude)")
        } catch {
            log.error("BGTask rain fetch failed: \(String(describing: error))")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func resolveCoordinate() async -> CLLocationCoordinate2D? {
        if let shared = SharedLocation.load() {
            return shared.coordinate
        }
        let manager = CLLocationManager()
        guard let cached = manager.location?.coordinate,
              NLBoundingBox.contains(cached) else { return nil }
        return cached
    }

    private func cache(rain: RainResponse) {
        let location = SharedLocation.load() ?? .amsterdamFallback
        let snap = SharedSnapshot(location: location,
                                  rain: rain,
                                  cachedAt: Date())
        SharedSnapshot.save(snap, as: .rain)
        // The current-conditions widget also reads `rain` for its verdict,
        // so refresh that cache slot too.
        let currentSnap = SharedSnapshot(location: location,
                                         weather: SharedSnapshot.load(.current)?.weather,
                                         rain: rain,
                                         cachedAt: Date())
        SharedSnapshot.save(currentSnap, as: .current)
    }
}
