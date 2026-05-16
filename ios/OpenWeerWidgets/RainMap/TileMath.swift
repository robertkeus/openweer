import Foundation
import CoreLocation

/// Web Mercator tile addressing. Pure functions, no side effects, so the
/// math can be unit-tested without WidgetKit.
struct TileCoord: Equatable, Hashable, Sendable {
    let z: Int
    let x: Int
    let y: Int
}

enum TileMath {
    /// Standard slippy-map tile size.
    static let tileSize: Int = 256

    /// Pixel coordinates (at the given zoom) for a lat/lon.
    static func pixel(for coord: CLLocationCoordinate2D, zoom: Int) -> (x: Double, y: Double) {
        let n = pow(2.0, Double(zoom))
        let latRad = coord.latitude * .pi / 180
        let x = (coord.longitude + 180) / 360 * n * Double(tileSize)
        let y = (1 - log(tan(latRad) + 1 / cos(latRad)) / .pi) / 2 * n * Double(tileSize)
        return (x, y)
    }

    /// Tile that contains the given coordinate.
    static func tile(for coord: CLLocationCoordinate2D, zoom: Int) -> TileCoord {
        let p = pixel(for: coord, zoom: zoom)
        return TileCoord(z: zoom,
                         x: Int(floor(p.x / Double(tileSize))),
                         y: Int(floor(p.y / Double(tileSize))))
    }

    /// 2×2 grid arranged so the user's location is as close to the centre of
    /// the resulting composite as possible. Also returns the user's pixel
    /// within that composite, which the loader uses to draw the location dot.
    static func grid2x2(for coord: CLLocationCoordinate2D, zoom: Int) -> Grid {
        let p = pixel(for: coord, zoom: zoom)
        let tileX = p.x / Double(tileSize)
        let tileY = p.y / Double(tileSize)
        let fracX = tileX - floor(tileX)
        let fracY = tileY - floor(tileY)

        // Pick the 2×2 anchor based on which half of the centre tile the user
        // sits in — keeps the user dot inside the inner 50% of the composite.
        let baseX = Int(floor(tileX)) - (fracX < 0.5 ? 1 : 0)
        let baseY = Int(floor(tileY)) - (fracY < 0.5 ? 1 : 0)

        let tiles: [[TileCoord]] = [
            [TileCoord(z: zoom, x: baseX,     y: baseY),
             TileCoord(z: zoom, x: baseX + 1, y: baseY)],
            [TileCoord(z: zoom, x: baseX,     y: baseY + 1),
             TileCoord(z: zoom, x: baseX + 1, y: baseY + 1)]
        ]
        let userX = p.x - Double(baseX * tileSize)
        let userY = p.y - Double(baseY * tileSize)
        return Grid(tiles: tiles, userPixel: (userX, userY))
    }

    struct Grid {
        let tiles: [[TileCoord]]
        let userPixel: (x: Double, y: Double)
    }
}
