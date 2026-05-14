import Foundation

/// Mirrors the web app's `defaultPlayableFrames`: anchor on the latest observed
/// frame, retain a 2 h history window, and accept forecast frames within the
/// user's chosen horizon. Hourly HARMONIE frames are clipped to fall in that
/// window so picking +2 h shows radar nowcast only.
enum PlayableFrames {
    /// Past observations retained on the slider, in seconds.
    private static let historyWindow: TimeInterval = 2 * 60 * 60

    static func filter(
        _ frames: [Frame],
        horizon: ForecastHorizon
    ) -> [Frame] {
        guard !frames.isEmpty else { return [] }
        let observed = frames.filter { $0.kind == .observed }
        let all = frames.sorted { $0.ts < $1.ts }
        let anchorTs: Date = observed.last?.ts ?? all.last!.ts
        let minTs = anchorTs.addingTimeInterval(-historyWindow)
        let maxTs = anchorTs.addingTimeInterval(TimeInterval(horizon.hours) * 3600)
        return all.filter { $0.ts >= minTs && $0.ts <= maxTs }
    }

    /// Index of the frame closest to wall-clock now, used to anchor the
    /// slider when the page loads.
    static func currentIndex(in playable: [Frame], now: Date = Date()) -> Int {
        guard !playable.isEmpty else { return 0 }
        var best = 0
        var bestDelta: TimeInterval = .infinity
        for (i, f) in playable.enumerated() {
            let d = abs(f.ts.timeIntervalSince(now))
            if d < bestDelta {
                bestDelta = d
                best = i
            }
        }
        return best
    }
}
