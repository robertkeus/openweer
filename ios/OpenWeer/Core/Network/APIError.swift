import Foundation

enum APIError: Error, CustomStringConvertible, Sendable {
    case invalidBaseURL
    case nonHTTPResponse
    case http(status: Int, path: String, body: String?)
    case decoding(path: String, underlying: Error)
    case outOfBounds(lat: Double, lon: Double)

    var description: String {
        switch self {
        case .invalidBaseURL:
            return "Invalid OPENWEER_API_BASE in Info.plist"
        case .nonHTTPResponse:
            return "Non-HTTP response"
        case .http(let status, let path, let body):
            return "HTTP \(status) for \(path)\(body.map { " — \($0)" } ?? "")"
        case .decoding(let path, let underlying):
            return "Decode failure for \(path): \(underlying)"
        case .outOfBounds(let lat, let lon):
            return "Coordinates outside NL bbox: \(lat),\(lon)"
        }
    }
}
