import Foundation

enum FrameKind: String, Codable, Sendable {
    case observed
    case nowcast
    case hourly
}

struct Frame: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let ts: Date
    let kind: FrameKind
    let cadenceMinutes: Int
    let maxZoom: Int

    enum CodingKeys: String, CodingKey {
        case id, ts, kind
        case cadenceMinutes = "cadence_minutes"
        case maxZoom = "max_zoom"
    }
}

struct FramesResponse: Codable, Sendable {
    let frames: [Frame]
    let generatedAt: Date

    enum CodingKeys: String, CodingKey {
        case frames
        case generatedAt = "generated_at"
    }
}
