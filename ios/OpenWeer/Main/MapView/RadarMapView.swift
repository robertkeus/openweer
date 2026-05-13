import SwiftUI
import MapLibre
import CoreLocation

/// Cross-fade between radar frames by pre-adding every frame as its own
/// raster source/layer (opacity 0) and animating only the opacity on swap.
/// MapLibre's `raster-opacity-transition` handles the interpolation, so
/// scrubbing the slider and auto-playback feel like a continuous dissolve
/// instead of a hard pop. Pre-adding also warms each frame's tile cache
/// before it becomes visible — no blank gap on swap.
struct RadarMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let frames: [Frame]
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
        context.coordinator.applyFrames(frames, currentId: frame?.id, baseURL: tileBaseURL)
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        if context.coordinator.currentBasemap != basemap {
            map.styleURL = basemap.url
            context.coordinator.currentBasemap = basemap
            // didFinishLoading on the new style will re-add from pending state.
            context.coordinator.applyFrames(frames, currentId: frame?.id,
                                            baseURL: tileBaseURL)
        } else {
            context.coordinator.applyFrames(frames, currentId: frame?.id,
                                            baseURL: tileBaseURL)
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
        /// Visible opacity for the active frame. Matches the pre-cross-fade
        /// look from the single-layer implementation.
        static let visibleOpacity: Float = 0.78
        /// Cross-fade duration. Matches the web client (`FADE_MS = 220`) so
        /// iOS and web playback feel identical, and so successive 220ms
        /// auto-play ticks chain into continuous motion instead of discrete
        /// steps.
        static let fadeDuration: TimeInterval = 0.22

        weak var map: MLNMapView?
        var currentBasemap: BasemapStyle?
        var didCenter = false

        /// IDs of frames currently materialised as sources+layers on the
        /// active style. Kept in sync with the desired set on each call.
        private var addedFrameIds: Set<String> = []
        /// Last desired state — re-applied verbatim after a basemap swap
        /// (which wipes all sources/layers from the new style).
        private var pendingFrames: [Frame] = []
        private var pendingCurrentId: String?
        private var pendingBaseURL: URL?

        func applyFrames(_ frames: [Frame], currentId: String?, baseURL: URL) {
            pendingFrames = frames
            pendingCurrentId = currentId
            pendingBaseURL = baseURL
            guard let map, let style = map.style else { return }
            reconcile(on: style, frames: frames, currentId: currentId, baseURL: baseURL)
        }

        private func reconcile(on style: MLNStyle,
                               frames: [Frame],
                               currentId: String?,
                               baseURL: URL) {
            let wanted = Set(frames.map { $0.id })

            // 1) Remove frames that are no longer wanted.
            for old in addedFrameIds.subtracting(wanted) {
                if let layer = style.layer(withIdentifier: "radar-\(old)-layer") {
                    style.removeLayer(layer)
                }
                if let src = style.source(withIdentifier: "radar-\(old)") {
                    style.removeSource(src)
                }
                addedFrameIds.remove(old)
            }

            // 2) Add brand-new frames as hidden (opacity 0) layers. They
            //    immediately start fetching tiles, which warms the cache so
            //    the cross-fade has no blank gap.
            let baseStr = Self.trimTrailingSlash(baseURL.absoluteString)
            for frame in frames where !addedFrameIds.contains(frame.id) {
                let sourceId = "radar-\(frame.id)"
                // String interpolation — NOT `URL.appendingPathComponent`,
                // which percent-encodes `{` and `}` and breaks MapLibre's
                // `{z}/{x}/{y}` placeholder substitution.
                let template = "\(baseStr)/tiles/\(frame.id)/{z}/{x}/{y}.png"
                let opts: [MLNTileSourceOption: Any] = [
                    .minimumZoomLevel: 6,
                    .maximumZoomLevel: NSNumber(value: frame.maxZoom),
                    .tileSize: 256,
                ]
                let source = MLNRasterTileSource(
                    identifier: sourceId,
                    tileURLTemplates: [template],
                    options: opts
                )
                style.addSource(source)
                let layer = MLNRasterStyleLayer(identifier: sourceId + "-layer",
                                                source: source)
                layer.rasterOpacity = NSExpression(forConstantValue: 0.0)
                layer.rasterOpacityTransition = MLNTransition(
                    duration: Self.fadeDuration, delay: 0
                )
                // Disable per-tile fade-in inside a single source. We control
                // visibility at the layer level via opacity transitions; the
                // per-tile fade would compound and look mushy.
                layer.rasterFadeDuration = NSExpression(forConstantValue: 0.0)
                style.addLayer(layer)
                addedFrameIds.insert(frame.id)
            }

            // 3) Drive opacities. Anything other than the active frame fades
            //    to 0; the active frame fades to `visibleOpacity`. MapLibre
            //    interpolates from the layer's current opacity (which may
            //    itself be mid-transition), so rapid playback chains into
            //    continuous motion instead of discrete pops.
            for frame in frames {
                guard let layer = style.layer(
                    withIdentifier: "radar-\(frame.id)-layer"
                ) as? MLNRasterStyleLayer else { continue }
                let target: Float = (frame.id == currentId) ? Self.visibleOpacity : 0.0
                layer.rasterOpacity = NSExpression(forConstantValue: target)
            }
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // Style swap wipes every source/layer. Re-materialise the last
            // desired state on the new style.
            addedFrameIds.removeAll()
            if !pendingFrames.isEmpty, let base = pendingBaseURL {
                reconcile(on: style,
                          frames: pendingFrames,
                          currentId: pendingCurrentId,
                          baseURL: base)
            }
        }

        private static func trimTrailingSlash(_ s: String) -> String {
            s.hasSuffix("/") ? String(s.dropLast()) : s
        }
    }
}
