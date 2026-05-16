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
        let horizon = now.addingTimeInterval(TimeInterval(withinMinutes * 60))
        let rainy = samples.contains { sample in
            sample.validAt >= now &&
            sample.validAt <= horizon &&
            sample.mmPerHour >= threshold
        }
        return rainy
            ? "Pak een paraplu mee"
            : "Droog komende \(withinMinutes) min"
    }
}
