import SwiftUI
import MapLibre
import CoreLocation

struct RadarMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let frame: Frame?
    let basemap: BasemapStyle
    let tileBaseURL: URL
    /// Height (pt) at the bottom of the view that's covered by the bottom
    /// sheet. The map applies this as `contentInset` so `setCenter` aims at
    /// the visible area instead of the geometric center.
    let bottomObscuredInset: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: basemap.url)
        map.tintColor = UIColor(named: "AccentColor")
        map.logoView.isHidden = false
        map.attributionButton.isHidden = false
        map.compassView.isHidden = false
        map.automaticallyAdjustsContentInset = false
        map.contentInset = UIEdgeInsets(top: 0, left: 0,
                                        bottom: bottomObscuredInset, right: 0)
        map.setCenter(coordinate, zoomLevel: 8, animated: false)
        map.minimumZoomLevel = 6
        map.maximumZoomLevel = 11
        map.delegate = context.coordinator
        context.coordinator.map = map
        context.coordinator.applyFrame(frame, baseURL: tileBaseURL)
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        if context.coordinator.currentBasemap != basemap {
            map.styleURL = basemap.url
            context.coordinator.currentBasemap = basemap
            context.coordinator.pendingFrame = frame
        } else {
            context.coordinator.applyFrame(frame, baseURL: tileBaseURL)
        }
        let newInsets = UIEdgeInsets(top: 0, left: 0,
                                     bottom: bottomObscuredInset, right: 0)
        if map.contentInset != newInsets {
            map.contentInset = newInsets
            // Re-aim at the active coordinate so it ends up at the new
            // visible center rather than wherever the prior inset left it.
            map.setCenter(coordinate, animated: true)
            context.coordinator.didCenter = true
        } else if !context.coordinator.didCenter {
            map.setCenter(coordinate, zoomLevel: 8, animated: false)
            context.coordinator.didCenter = true
        } else if !areClose(map.centerCoordinate, coordinate) {
            map.setCenter(coordinate, animated: true)
        }
    }

    private func areClose(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 0.001 && abs(a.longitude - b.longitude) < 0.001
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate {
        weak var map: MLNMapView?
        var currentBasemap: BasemapStyle?
        var didCenter = false
        var currentSourceId: String?
        var pendingFrame: Frame?

        func applyFrame(_ frame: Frame?, baseURL: URL) {
            guard let map, let style = map.style, let frame else { return }
            let newId = "radar-" + frame.id
            if currentSourceId == newId { return }
            if let prev = currentSourceId,
               let layer = style.layer(withIdentifier: prev + "-layer") {
                style.removeLayer(layer)
            }
            if let prev = currentSourceId,
               let src = style.source(withIdentifier: prev) {
                style.removeSource(src)
            }
            let template = baseURL
                .appendingPathComponent("/tiles/\(frame.id)/{z}/{x}/{y}.png")
                .absoluteString
            let opts: [MLNTileSourceOption: Any] = [
                .minimumZoomLevel: 6,
                .maximumZoomLevel: NSNumber(value: frame.maxZoom),
                .tileSize: 256,
            ]
            let source = MLNRasterTileSource(
                identifier: newId,
                tileURLTemplates: [template],
                options: opts
            )
            style.addSource(source)
            let layer = MLNRasterStyleLayer(identifier: newId + "-layer", source: source)
            layer.rasterOpacity = NSExpression(forConstantValue: 0.78)
            style.addLayer(layer)
            currentSourceId = newId
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // After a style swap, the previous source is gone. Re-add the
            // pending frame on the new style.
            if let frame = pendingFrame {
                currentSourceId = nil
                applyFrame(frame, baseURL: defaultBaseURL())
                pendingFrame = nil
            }
        }

        private func defaultBaseURL() -> URL {
            let str = (Bundle.main.object(forInfoDictionaryKey: "OPENWEER_API_BASE") as? String)
                ?? "https://openweer.nl"
            return URL(string: str) ?? URL(string: "https://openweer.nl")!
        }
    }
}

