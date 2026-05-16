import XCTest
@testable import OpenWeer

final class SharedLocationTests: XCTestCase {
    /// Use a per-test in-memory suite so we don't bleed state across runs.
    private func freshDefaults() -> UserDefaults {
        let name = "test.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func test_roundTrip() {
        let d = freshDefaults()
        let original = SharedLocation(latitude: 52.37,
                                      longitude: 4.90,
                                      name: "Amsterdam",
                                      updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        SharedLocation.save(original, to: d)
        let loaded = SharedLocation.load(from: d)
        XCTAssertEqual(loaded, original)
    }

    func test_loadMissingReturnsNil() {
        XCTAssertNil(SharedLocation.load(from: freshDefaults()))
    }

    func test_saveByCoordinate() {
        let d = freshDefaults()
        SharedLocation.save(coordinate: .init(latitude: 51.92, longitude: 4.48),
                            name: "Rotterdam",
                            to: d)
        let loaded = SharedLocation.load(from: d)
        XCTAssertEqual(loaded?.name, "Rotterdam")
        XCTAssertEqual(loaded?.latitude ?? 0, 51.92, accuracy: 0.0001)
    }

    func test_amsterdamFallback() {
        let fallback = SharedLocation.amsterdamFallback
        XCTAssertEqual(fallback.name, "Amsterdam")
        XCTAssertEqual(fallback.latitude, 52.3676, accuracy: 0.0001)
    }
}
