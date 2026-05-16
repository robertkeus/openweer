import Foundation
import os

/// Debounced background sync of the local favorites set up to the backend.
///
/// `schedule()` is cheap and idempotent — UI handlers call it after every
/// edit; we coalesce edits into a single PUT after a short delay.
@MainActor
final class FavoritesSync {
    static let shared = FavoritesSync()

    private let log = Logger(subsystem: "nl.openweer.app", category: "favorites.sync")
    private let store: FavoritesStore
    private let api: APIClient
    private var debounceTask: Task<Void, Never>?
    private let debounceMillis: UInt64 = 1_000

    init(store: FavoritesStore = .shared, api: APIClient = .shared) {
        self.store = store
        self.api = api
    }

    /// Trigger a debounced sync. Safe to call repeatedly.
    func schedule() {
        guard PushService.shared.deviceToken != nil else {
            log.debug("schedule: no device token yet — deferring")
            return
        }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000 * (self?.debounceMillis ?? 1000))
            if Task.isCancelled { return }
            await self?.syncNow()
        }
    }

    /// Immediate sync — used on app launch and after token receipt.
    func syncNow() async {
        guard let token = PushService.shared.deviceToken else { return }
        guard store.needsSync else { return }
        let snapshot = store.favorites
        do {
            try await api.putFavorites(token: token, favorites: snapshot)
            store.markSynced()
            log.debug("synced \(snapshot.count) favorites")
        } catch {
            log.error("favorites sync failed: \(error.localizedDescription)")
        }
    }
}
