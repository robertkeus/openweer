import Foundation
import CoreLocation

actor APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL ?? Self.resolveBaseURL()
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let str = try dec.singleValueContainer().decode(String.self)
            if let d = ISO8601DateFormatter.withFractional.date(from: str) { return d }
            if let d = ISO8601DateFormatter.plain.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(in: try dec.singleValueContainer(),
                                                   debugDescription: "Bad ISO8601 date: \(str)")
        }
        self.decoder = decoder
    }

    private static func resolveBaseURL() -> URL {
        let str = (Bundle.main.object(forInfoDictionaryKey: "OPENWEER_API_BASE") as? String)
            ?? "https://openweer.nl"
        return URL(string: str) ?? URL(string: "https://openweer.nl")!
    }

    // MARK: - Public endpoints

    func health() async throws -> HealthResponse {
        try await get("/api/health", as: HealthResponse.self)
    }

    func frames() async throws -> FramesResponse {
        try await get("/api/frames", as: FramesResponse.self)
    }

    func rain(at coord: CLLocationCoordinate2D) async throws -> RainResponse {
        try guardNL(coord)
        return try await get("/api/rain/\(fmt(coord.latitude))/\(fmt(coord.longitude))",
                             as: RainResponse.self)
    }

    func weather(at coord: CLLocationCoordinate2D) async throws -> WeatherResponse {
        try guardNL(coord)
        return try await get("/api/weather/\(fmt(coord.latitude))/\(fmt(coord.longitude))",
                             as: WeatherResponse.self)
    }

    func forecast(at coord: CLLocationCoordinate2D) async throws -> ForecastResponse {
        try guardNL(coord)
        return try await get("/api/forecast/\(fmt(coord.latitude))/\(fmt(coord.longitude))",
                             as: ForecastResponse.self)
    }

    func tileURL(frameId: String, z: Int, x: Int, y: Int) -> URL {
        baseURL.appendingPathComponent("/tiles/\(frameId)/\(z)/\(x)/\(y).png")
    }

    // MARK: - Internals

    private func fmt(_ v: Double) -> String {
        String(format: "%.4f", v)
    }

    private func guardNL(_ c: CLLocationCoordinate2D) throws {
        guard NLBoundingBox.contains(c) else {
            throw APIError.outOfBounds(lat: c.latitude, lon: c.longitude)
        }
    }

    private func get<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        try await getInternal(path, as: T.self)
    }

    func getInternal<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        try await request(method: "GET", path: path, body: Optional<Empty>.none, as: T.self)
    }

    func postJSONInternal<B: Encodable, T: Decodable>(
        _ path: String, body: B, as: T.Type
    ) async throws -> T {
        try await request(method: "POST", path: path, body: body, as: T.self)
    }

    func putJSONInternal<B: Encodable, T: Decodable>(
        _ path: String, body: B, as: T.Type
    ) async throws -> T {
        try await request(method: "PUT", path: path, body: body, as: T.self)
    }

    func deleteInternal(_ path: String) async throws {
        _ = try await request(method: "DELETE", path: path, body: Optional<Empty>.none, as: Empty.self, allowEmptyBody: true)
    }

    struct Empty: Codable {}

    private func request<B: Encodable, T: Decodable>(
        method: String,
        path: String,
        body: B?,
        as: T.Type,
        allowEmptyBody: Bool = false
    ) async throws -> T {
        guard path.hasPrefix("/") else { throw APIError.invalidBaseURL }
        let url = baseURL.appendingPathComponent(String(path.dropFirst()))
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.nonHTTPResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, path: path,
                                body: String(data: data, encoding: .utf8))
        }
        if allowEmptyBody && data.isEmpty {
            // Caller asked for Empty + 204 No Content path.
            return try decoder.decode(T.self, from: Data("{}".utf8))
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(path: path, underlying: error)
        }
    }
}

private extension ISO8601DateFormatter {
    nonisolated(unsafe) static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
