import Foundation

struct DatasetFreshness: Codable, Hashable, Sendable {
    let dataset: String
    let filename: String?
    let ingestedAt: Date?

    enum CodingKeys: String, CodingKey {
        case dataset, filename
        case ingestedAt = "ingested_at"
    }
}

struct HealthResponse: Codable, Hashable, Sendable {
    let ok: Bool
    let version: String
    let datasets: [DatasetFreshness]
}
