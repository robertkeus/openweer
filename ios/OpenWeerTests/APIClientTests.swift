import XCTest
import CoreLocation
@testable import OpenWeer

final class APIClientTests: XCTestCase {
    func test_decodeFramesResponse() throws {
        let json = #"""
        {
          "frames": [
            {"id":"obs-202605091200","ts":"2026-05-09T12:00:00Z","kind":"observed","cadence_minutes":5,"max_zoom":9}
          ],
          "generated_at":"2026-05-09T12:01:00Z"
        }
        """#.data(using: .utf8)!
        let dec = makeDecoder()
        let resp = try dec.decode(FramesResponse.self, from: json)
        XCTAssertEqual(resp.frames.count, 1)
        XCTAssertEqual(resp.frames[0].kind, .observed)
        XCTAssertEqual(resp.frames[0].cadenceMinutes, 5)
    }

    func test_decodeRainResponse() throws {
        let json = #"""
        {
          "lat":52.37,"lon":4.90,
          "analysis_at":"2026-05-09T12:00:00Z",
          "samples":[
            {"minutes_ahead":0,"mm_per_h":0.0,"valid_at":"2026-05-09T12:00:00Z"},
            {"minutes_ahead":5,"mm_per_h":1.2,"valid_at":"2026-05-09T12:05:00Z"}
          ]
        }
        """#.data(using: .utf8)!
        let dec = makeDecoder()
        let resp = try dec.decode(RainResponse.self, from: json)
        XCTAssertEqual(resp.samples.count, 2)
        XCTAssertTrue(resp.willRain(withinMinutes: 30, threshold: 0.5))
    }

    func test_decodeWeatherResponse() throws {
        let json = #"""
        {
          "station": {"name":"Schiphol","id":"240","lat":52.3,"lon":4.78,"distance_km":12.4},
          "current": {
            "observed_at":"2026-05-09T12:00:00Z",
            "temperature_c":18.4,"feels_like_c":17.0,
            "condition":"partly-cloudy","condition_label":"halfbewolkt",
            "wind_speed_mps":4.5,"wind_speed_bft":3,
            "wind_direction_deg":180,"wind_direction_compass":"Z",
            "humidity_pct":65,"pressure_hpa":1015.2,
            "rainfall_1h_mm":0.0,"rainfall_24h_mm":1.2,
            "cloud_cover_octas":4,"visibility_m":15000
          }
        }
        """#.data(using: .utf8)!
        let dec = makeDecoder()
        let resp = try dec.decode(WeatherResponse.self, from: json)
        XCTAssertEqual(resp.station.name, "Schiphol")
        XCTAssertEqual(resp.current.condition, .partlyCloudy)
        XCTAssertEqual(resp.current.windSpeedBft, 3)
    }

    func test_nlBoundingBoxGuard() {
        XCTAssertTrue(NLBoundingBox.contains(.init(latitude: 52.37, longitude: 4.90)))
        XCTAssertFalse(NLBoundingBox.contains(.init(latitude: 48.85, longitude: 2.35))) // Paris
    }

    private func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
