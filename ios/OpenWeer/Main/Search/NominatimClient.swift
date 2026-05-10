import Foundation
import CoreLocation

struct NominatimResult: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let shortName: String
    let coordinate: CLLocationCoordinate2D

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: NominatimResult, rhs: NominatimResult) -> Bool { lhs.id == rhs.id }
}

/// Tiny client for the Nominatim /search endpoint, restricted to NL.
/// Same contract the web app uses (per CLAUDE.md SSRF allowlist).
struct NominatimClient {
    static let host = "https://nominatim.openstreetmap.org"

    func search(_ query: String) async throws -> [NominatimResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        var components = URLComponents(string: "\(Self.host)/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "addressdetails", value: "1"),
            URLQueryItem(name: "limit", value: "8"),
            URLQueryItem(name: "countrycodes", value: "nl"),
            URLQueryItem(name: "accept-language", value: "nl"),
        ]
        guard let url = components.url else { return [] }

        var req = URLRequest(url: url)
        req.setValue("OpenWeer iOS (mail@openweer.nl)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return []
        }
        let raw = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        return raw.compactMap { dict -> NominatimResult? in
            guard let osmId = dict["place_id"].flatMap({ "\($0)" }),
                  let latStr = dict["lat"] as? String, let lat = Double(latStr),
                  let lonStr = dict["lon"] as? String, let lon = Double(lonStr) else {
                return nil
            }
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            guard NLBoundingBox.contains(coord) else { return nil }
            let display = dict["display_name"] as? String ?? "—"
            let short = (dict["name"] as? String)
                ?? Self.shortenDisplayName(display)
            return NominatimResult(id: osmId, displayName: display,
                                    shortName: short, coordinate: coord)
        }
    }

    private static func shortenDisplayName(_ s: String) -> String {
        s.split(separator: ",", maxSplits: 1).first.map(String.init) ?? s
    }
}
