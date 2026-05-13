import Foundation
import CoreLocation
import os

@MainActor
final class PushRegistration {
    static let shared = PushRegistration()

    private let log = Logger(subsystem: "nl.openweer.app", category: "push.register")
    private var pendingToken: String?

    private init() {}

    func uploadIfReady(token: String) async {
        pendingToken = token
        // Coords + language are known via AppState; the actual POST is
        // performed from MainView/onboarding once those are settled.
        log.debug("token captured, awaiting coords")
    }

    func register(
        token: String,
        coordinate: CLLocationCoordinate2D,
        language: LanguagePreference
    ) async {
        guard let baseStr = Bundle.main.object(forInfoDictionaryKey: "OPENWEER_API_BASE") as? String,
              let url = URL(string: baseStr)?.appendingPathComponent("/api/push/register")
        else { return }

        let body: [String: Any] = [
            "device_token": token,
            "lat": (coordinate.latitude  * 100).rounded() / 100,
            "lon": (coordinate.longitude * 100).rounded() / 100,
            "language": language.rawValue,
        ]
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                log.error("register HTTP \(http.statusCode)")
            }
        } catch {
            log.error("register failed: \(error.localizedDescription)")
        }
    }
}
