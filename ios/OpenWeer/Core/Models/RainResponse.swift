import Foundation

struct RainSample: Codable, Hashable, Sendable {
    let minutesAhead: Int
    let mmPerHour: Double
    let validAt: Date

    enum CodingKeys: String, CodingKey {
        case minutesAhead = "minutes_ahead"
        case mmPerHour = "mm_per_h"
        case validAt = "valid_at"
    }
}

struct RainResponse: Codable, Hashable, Sendable {
    let lat: Double
    let lon: Double
    let analysisAt: Date
    let samples: [RainSample]

    enum CodingKeys: String, CodingKey {
        case lat, lon, samples
        case analysisAt = "analysis_at"
    }

    /// Will any sample exceed `threshold` mm/h within the next `withinMinutes`?
    func willRain(withinMinutes: Int = 30, threshold: Double = 0.5) -> Bool {
        samples.contains {
            $0.minutesAhead > 0 &&
            $0.minutesAhead <= withinMinutes &&
            $0.mmPerHour >= threshold
        }
    }

    /// Short go/no-go for stepping outside in the next `withinMinutes`.
    func outsideVerdict(now: Date = Date(),
                        withinMinutes: Int = 15,
                        threshold: Double = 0.2) -> String {
        switch outlook(now: now, withinMinutes: withinMinutes, threshold: threshold) {
        case .rainingNow:           return "Het regent nu"
        case .startsSoon(let date): return "Regen om \(Self.hhmm.string(from: date))"
        case .stopsSoon(let date):  return "Droog vanaf \(Self.hhmm.string(from: date))"
        case .dry:                  return "Het blijft droog"
        }
    }

    /// Tri-state outlook used by the widgets and Live Activity. Cheap to
    /// compute; pure so we can unit-test the corner cases.
    enum Outlook: Equatable {
        case rainingNow
        case startsSoon(at: Date)
        case stopsSoon(at: Date)
        case dry
    }

    func outlook(now: Date = Date(),
                 withinMinutes: Int = 15,
                 threshold: Double = 0.2) -> Outlook {
        let nowSample = samples.min(by: {
            abs($0.validAt.timeIntervalSince(now)) < abs($1.validAt.timeIntervalSince(now))
        })
        let raining = (nowSample?.mmPerHour ?? 0) >= threshold

        let horizon = now.addingTimeInterval(TimeInterval(withinMinutes * 60))
        let upcoming = samples.filter { $0.validAt > now && $0.validAt <= horizon }

        if raining {
            if let stops = upcoming.first(where: { $0.mmPerHour < threshold }) {
                return .stopsSoon(at: stops.validAt)
            }
            return .rainingNow
        } else {
            if let starts = upcoming.first(where: { $0.mmPerHour >= threshold }) {
                return .startsSoon(at: starts.validAt)
            }
            return .dry
        }
    }

    private static let hhmm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
