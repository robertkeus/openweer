import Foundation
import SwiftUI

/// View-model for the rain widgets: the tri-state outlook turned into a
/// big-typography "hero" string + a softer detail line + an optional
/// countdown. Kept pure so we can iterate on copy without touching the views.
struct RainSummary {
    let hero: String
    let detail: String
    let tint: Color
    /// Minutes until rain starts/stops, when meaningful.
    let countdownMinutes: Int?

    init(rain: RainResponse?, now: Date) {
        guard let rain else {
            self.hero = "—"
            self.detail = "Bezig met laden"
            self.tint = .owInkSecondary
            self.countdownMinutes = nil
            return
        }
        switch rain.outlook(now: now) {
        case .rainingNow:
            self.hero = "Nat"
            self.detail = "Het regent op jouw plek"
            self.tint = .owAccent
            self.countdownMinutes = nil
        case .startsSoon(let at):
            self.hero = "Regen op komst"
            self.detail = "Begint om \(Self.hhmm(at))"
            self.tint = .owAccent
            self.countdownMinutes = max(0, Int(at.timeIntervalSince(now) / 60))
        case .stopsSoon(let at):
            self.hero = "Bijna droog"
            self.detail = "Vanaf \(Self.hhmm(at))"
            self.tint = .owAccent
            self.countdownMinutes = max(0, Int(at.timeIntervalSince(now) / 60))
        case .dry:
            self.hero = "Droog"
            self.detail = "Komende twee uur"
            self.tint = .owInkPrimary
            self.countdownMinutes = nil
        }
    }

    private static func hhmm(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

/// Slices the raw rain samples into a window we want to render. The Buienradar
/// nowcast returns roughly -120…+120 min around the analysis time; we trim
/// that to a tighter window and remember which index is "now".
enum RainWindow {
    struct Snapshot {
        let samples: [RainSample]
        let nowIndex: Int?
    }

    /// Small widget — past 30 min + next 90 min. Keeps the chart legible at
    /// a glance without crowding the bars.
    static func recent(from samples: [RainSample], now: Date) -> Snapshot {
        slice(samples, now: now, beforeMin: -30, afterMin: 90)
    }

    /// Medium widget — past 30 min + next 120 min. Same window as the
    /// flagship in-app rain sheet, so users get a familiar shape.
    static func standard(from samples: [RainSample], now: Date) -> Snapshot {
        slice(samples, now: now, beforeMin: -30, afterMin: 120)
    }

    private static func slice(_ samples: [RainSample],
                              now: Date,
                              beforeMin: Int,
                              afterMin: Int) -> Snapshot {
        let lower = now.addingTimeInterval(TimeInterval(beforeMin * 60))
        let upper = now.addingTimeInterval(TimeInterval(afterMin * 60))
        let filtered = samples.filter { $0.validAt >= lower && $0.validAt <= upper }
        guard !filtered.isEmpty else { return Snapshot(samples: [], nowIndex: nil) }
        let nowIndex = filtered.enumerated().min(by: {
            abs($0.element.validAt.timeIntervalSince(now)) <
            abs($1.element.validAt.timeIntervalSince(now))
        })?.offset
        return Snapshot(samples: filtered, nowIndex: nowIndex)
    }
}
