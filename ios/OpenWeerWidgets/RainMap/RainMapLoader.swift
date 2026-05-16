import Foundation
import UIKit
import CoreLocation
import os

private let log = Logger(subsystem: "nl.openweer.app.widgets", category: "rainmap")

/// Fetches the latest observed radar frame, downloads the 2×2 tile grid
/// surrounding the user, and composites it (plus a location dot) into a
/// single PNG so the widget can render the result with a plain `Image`.
enum RainMapLoader {

    /// Zoom 9 is roughly 75 km across at this latitude — wide enough to see
    /// a weather front approach, tight enough to recognise the local area.
    static let zoom: Int = 9

    static func fetch(for coord: CLLocationCoordinate2D) async throws -> Data? {
        let framesResponse = try await APIClient.shared.frames()
        let observed = framesResponse.frames
            .filter { $0.kind == .observed }
            .sorted(by: { $0.ts < $1.ts })
        guard let latest = observed.last else {
            log.error("no observed frames available")
            return nil
        }

        let grid = TileMath.grid2x2(for: coord, zoom: zoom)
        let flatTiles = grid.tiles.flatMap { $0 }

        // Resolve URLs once, then download in parallel.
        var urls: [URL] = []
        for tile in flatTiles {
            urls.append(await APIClient.shared.tileURL(frameId: latest.id,
                                                       z: tile.z, x: tile.x, y: tile.y))
        }

        let images = try await withThrowingTaskGroup(of: (Int, UIImage?).self) { group in
            for (i, url) in urls.enumerated() {
                group.addTask {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        return (i, UIImage(data: data))
                    } catch {
                        return (i, nil)
                    }
                }
            }
            var result: [Int: UIImage] = [:]
            for try await (i, img) in group {
                if let img { result[i] = img }
            }
            return result
        }

        return composite(images: images, userPixel: grid.userPixel)
    }

    // MARK: - Compositing

    private static func composite(images: [Int: UIImage],
                                  userPixel: (x: Double, y: Double)) -> Data? {
        let side = TileMath.tileSize * 2  // 512
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size, format: imageFormat())
        let composite = renderer.image { ctx in
            // Surface fill that matches the widget background in both schemes.
            UIColor(named: "SurfaceBackground")?.setFill() ?? UIColor.systemGray6.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            for i in 0..<4 {
                guard let img = images[i] else { continue }
                let row = i / 2
                let col = i % 2
                img.draw(in: CGRect(x: col * TileMath.tileSize,
                                    y: row * TileMath.tileSize,
                                    width: TileMath.tileSize,
                                    height: TileMath.tileSize))
            }

            drawLocationDot(at: userPixel, in: ctx.cgContext)
        }
        return composite.pngData()
    }

    private static func imageFormat() -> UIGraphicsImageRendererFormat {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.opaque = true
        fmt.scale = 1                       // tiles are 1:1, no need for @2x
        return fmt
    }

    private static func drawLocationDot(at p: (x: Double, y: Double),
                                        in ctx: CGContext) {
        let dot: CGFloat = 14
        let halo: CGFloat = 22

        // Soft halo for visibility on busy radar.
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
        ctx.fillEllipse(in: CGRect(x: CGFloat(p.x) - halo / 2,
                                   y: CGFloat(p.y) - halo / 2,
                                   width: halo, height: halo))

        // Solid accent dot.
        let accent = UIColor(named: "AccentColor") ?? UIColor.systemBlue
        ctx.setFillColor(accent.cgColor)
        ctx.fillEllipse(in: CGRect(x: CGFloat(p.x) - dot / 2,
                                   y: CGFloat(p.y) - dot / 2,
                                   width: dot, height: dot))

        // White outline.
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: CGFloat(p.x) - dot / 2,
                                     y: CGFloat(p.y) - dot / 2,
                                     width: dot, height: dot))
    }
}
