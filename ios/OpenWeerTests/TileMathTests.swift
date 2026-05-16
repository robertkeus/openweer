import XCTest
import CoreLocation
@testable import OpenWeer

final class TileMathTests: XCTestCase {

    /// Amsterdam at zoom 9 falls in the well-known tile (262, 168) — the
    /// reference values come from the standard slippy-map formulas.
    func test_tileForAmsterdamAtZoom9() {
        let amsterdam = CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)
        let tile = TileMath.tile(for: amsterdam, zoom: 9)
        XCTAssertEqual(tile.z, 9)
        XCTAssertEqual(tile.x, 262)
        XCTAssertEqual(tile.y, 168)
    }

    func test_grid2x2_userPixelLandsInsideComposite() {
        let amsterdam = CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)
        let grid = TileMath.grid2x2(for: amsterdam, zoom: 9)
        let side = Double(TileMath.tileSize * 2)
        XCTAssertGreaterThan(grid.userPixel.x, 0)
        XCTAssertLessThan(grid.userPixel.x, side)
        XCTAssertGreaterThan(grid.userPixel.y, 0)
        XCTAssertLessThan(grid.userPixel.y, side)
    }

    func test_grid2x2_userIsRoughlyCentered() {
        // For any NL coordinate the user should be in the inner 50% of the
        // 512x512 composite (i.e. between 128 and 384 on both axes).
        let coords: [CLLocationCoordinate2D] = [
            .init(latitude: 52.3676, longitude: 4.9041), // Amsterdam
            .init(latitude: 51.9244, longitude: 4.4777), // Rotterdam
            .init(latitude: 53.2194, longitude: 6.5665), // Groningen
            .init(latitude: 50.8514, longitude: 5.6910)  // Maastricht
        ]
        for c in coords {
            let grid = TileMath.grid2x2(for: c, zoom: 9)
            XCTAssertGreaterThanOrEqual(grid.userPixel.x, 128, "x for \(c.latitude),\(c.longitude)")
            XCTAssertLessThanOrEqual(grid.userPixel.x, 384, "x for \(c.latitude),\(c.longitude)")
            XCTAssertGreaterThanOrEqual(grid.userPixel.y, 128, "y for \(c.latitude),\(c.longitude)")
            XCTAssertLessThanOrEqual(grid.userPixel.y, 384, "y for \(c.latitude),\(c.longitude)")
        }
    }
}
