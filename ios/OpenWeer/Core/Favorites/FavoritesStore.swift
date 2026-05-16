import Foundation
import Observation

/// Persistent, app-group-shared store of the user's favorite locations.
///
/// Backed by `AppGroup.userDefaults` so widgets and the main app can read
/// the same list. Caps the list at `Self.maxCount` — matches the backend
/// `MAX_FAVORITES_PER_DEVICE`, exposed here so the UI can disable the "add"
/// button before hitting the server.
@MainActor
@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    static let maxCount = 5
    private static let storageKey = "favorites.v1"

    private(set) var favorites: [Favorite] = []
    private(set) var lastSyncedHash: Int = 0

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? AppGroup.userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.favorites = Self.load(from: self.defaults, decoder: decoder)
        self.lastSyncedHash = persistedSyncHash()
    }

    // MARK: - CRUD

    var canAdd: Bool { favorites.count < Self.maxCount }

    @discardableResult
    func add(_ favorite: Favorite) -> Bool {
        guard canAdd else { return false }
        guard !favorites.contains(where: { $0.id == favorite.id }) else { return false }
        favorites.append(favorite)
        persist()
        return true
    }

    func update(_ favorite: Favorite) {
        guard let idx = favorites.firstIndex(where: { $0.id == favorite.id }) else { return }
        favorites[idx] = favorite
        persist()
    }

    func remove(id: UUID) {
        favorites.removeAll { $0.id == id }
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    // MARK: - Sync bookkeeping

    /// Recorded after a successful PUT to mark the current set as in-sync.
    func markSynced() {
        lastSyncedHash = currentHash()
        defaults.set(lastSyncedHash, forKey: Self.storageKey + ".syncHash")
    }

    var needsSync: Bool { currentHash() != lastSyncedHash }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try encoder.encode(favorites)
            defaults.set(data, forKey: Self.storageKey)
        } catch {
            assertionFailure("Failed to persist favorites: \(error)")
        }
    }

    private static func load(from defaults: UserDefaults, decoder: JSONDecoder) -> [Favorite] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? decoder.decode([Favorite].self, from: data)) ?? []
    }

    private func currentHash() -> Int {
        var hasher = Hasher()
        for f in favorites { hasher.combine(f) }
        return hasher.finalize()
    }

    private func persistedSyncHash() -> Int {
        defaults.integer(forKey: Self.storageKey + ".syncHash")
    }
}
