import Foundation
import CoreLocation

/// Minimal Server-Sent-Events client for /api/chat. Emits OpenAI-compatible
/// chunk strings (the `data:` payloads). Caller is responsible for stopping
/// the stream by cancelling the parent Task.
struct ChatStreamClient {
    let baseURL: URL

    init(baseURL: URL? = nil) {
        if let baseURL { self.baseURL = baseURL }
        else {
            let str = (Bundle.main.object(forInfoDictionaryKey: "OPENWEER_API_BASE") as? String)
                ?? "https://openweer.nl"
            self.baseURL = URL(string: str) ?? URL(string: "https://openweer.nl")!
        }
    }

    /// Streams assistant message deltas. The closure receives each new token
    /// (already extracted from the OpenAI-style `choices[0].delta.content`).
    /// Returns when the server signals `[DONE]` or the task is cancelled.
    func stream(
        messages: [ChatMessage],
        coordinate: CLLocationCoordinate2D,
        language: LanguagePreference,
        locationName: String,
        onDelta: @MainActor @Sendable @escaping (String) -> Void
    ) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/chat"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 60

        let body: [String: Any] = [
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "context": [
                "lat": (coordinate.latitude * 10000).rounded() / 10000,
                "lon": (coordinate.longitude * 10000).rounded() / 10000,
                "language": language.rawValue,
                "location_name": locationName
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.nonHTTPResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, path: "/api/chat", body: nil)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { return }
            guard let data = payload.data(using: .utf8) else { continue }
            if let chunk = try? JSONDecoder().decode(OpenAIChunk.self, from: data),
               let delta = chunk.choices.first?.delta.content,
               !delta.isEmpty {
                await onDelta(delta)
            }
        }
    }
}

private struct OpenAIChunk: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}
