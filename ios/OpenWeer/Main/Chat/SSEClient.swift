import Foundation
import CoreLocation

/// Mirrors the payload shape built by `web/app/lib/ai-chat.ts → buildContext`.
struct ChatContext: Encodable {
    let location_name: String
    let lat: Double
    let lon: Double
    let cursor_at: String?
    let samples: [Sample]
    let language: String
    let theme: String

    struct Sample: Encodable {
        let minutes_ahead: Int
        let mm_per_h: Double
        let valid_at: String
    }

    init(locationName: String,
         coordinate: CLLocationCoordinate2D,
         cursorFrame: Frame?,
         rain: RainResponse?,
         language: LanguagePreference,
         isDark: Bool) {
        self.location_name = locationName
        // Round to 2 decimals on the wire for privacy (matches web).
        self.lat = (coordinate.latitude  * 100).rounded() / 100
        self.lon = (coordinate.longitude * 100).rounded() / 100
        let isoFmt = ISO8601DateFormatter()
        self.cursor_at = cursorFrame.map { isoFmt.string(from: $0.ts) }
        self.samples = (rain?.samples ?? []).map { s in
            Sample(minutes_ahead: s.minutesAhead,
                   mm_per_h: s.mmPerHour,
                   valid_at: isoFmt.string(from: s.validAt))
        }
        self.language = language.rawValue
        self.theme = isDark ? "dark" : "light"
    }
}

/// Minimal Server-Sent-Events client for /api/chat. Streams OpenAI-compatible
/// chunks and emits each `delta.content` token via the callback.
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

    func stream(
        messages: [ChatMessage],
        context: ChatContext,
        onDelta: @MainActor @Sendable @escaping (String) -> Void
    ) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("/api/chat"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 60

        struct Body: Encodable {
            struct Msg: Encodable {
                let role: String
                let content: String
            }
            let messages: [Msg]
            let context: ChatContext
        }
        let body = Body(
            messages: messages.map { Body.Msg(role: $0.role.rawValue, content: $0.content) },
            context: context
        )
        req.httpBody = try JSONEncoder().encode(body)

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
