import XCTest
import CoreLocation
@testable import OpenWeer

@MainActor
final class FavoritesStoreTests: XCTestCase {
    /// Per-test in-memory suite — keeps real app-group state untouched.
    private func freshDefaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func sampleFavorite(label: String = "Home") -> Favorite {
        Favorite(
            label: label,
            coordinate: CLLocationCoordinate2D(latitude: 52.37, longitude: 4.89)
        )
    }

    func test_addPersistsAndIsObservable() {
        let store = FavoritesStore(defaults: freshDefaults())
        XCTAssertTrue(store.favorites.isEmpty)
        XCTAssertTrue(store.add(sampleFavorite()))
        XCTAssertEqual(store.favorites.count, 1)
    }

    func test_addRespectsMaxCount() {
        let store = FavoritesStore(defaults: freshDefaults())
        for i in 0..<FavoritesStore.maxCount {
            XCTAssertTrue(store.add(sampleFavorite(label: "Plek \(i)")))
        }
        XCTAssertFalse(store.canAdd)
        XCTAssertFalse(store.add(sampleFavorite(label: "Eentje teveel")))
        XCTAssertEqual(store.favorites.count, FavoritesStore.maxCount)
    }

    func test_removeById() {
        let store = FavoritesStore(defaults: freshDefaults())
        let fav = sampleFavorite()
        store.add(fav)
        store.remove(id: fav.id)
        XCTAssertTrue(store.favorites.isEmpty)
    }

    func test_persistenceSurvivesReinit() {
        let defaults = freshDefaults()
        let first = FavoritesStore(defaults: defaults)
        first.add(sampleFavorite(label: "Home"))
        first.add(sampleFavorite(label: "Werk"))

        let second = FavoritesStore(defaults: defaults)
        XCTAssertEqual(second.favorites.count, 2)
        XCTAssertEqual(second.favorites.map(\.label), ["Home", "Werk"])
    }

    func test_coordsAreRoundedToTwoDecimals() {
        let store = FavoritesStore(defaults: freshDefaults())
        let f = Favorite(
            label: "Test",
            coordinate: CLLocationCoordinate2D(latitude: 52.37345, longitude: 4.89234)
        )
        store.add(f)
        XCTAssertEqual(store.favorites[0].latitude, 52.37, accuracy: 1e-9)
        XCTAssertEqual(store.favorites[0].longitude, 4.89, accuracy: 1e-9)
    }

    func test_needsSyncAfterEdit() {
        let store = FavoritesStore(defaults: freshDefaults())
        store.markSynced()
        XCTAssertFalse(store.needsSync)
        store.add(sampleFavorite())
        XCTAssertTrue(store.needsSync)
        store.markSynced()
        XCTAssertFalse(store.needsSync)
    }

    func test_moveReordersFavorites() {
        let store = FavoritesStore(defaults: freshDefaults())
        store.add(sampleFavorite(label: "A"))
        store.add(sampleFavorite(label: "B"))
        store.add(sampleFavorite(label: "C"))
        store.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(store.favorites.map(\.label), ["B", "C", "A"])
    }
}
