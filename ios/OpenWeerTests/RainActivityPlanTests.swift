import XCTest
@testable import OpenWeer

final class RainActivityPlanTests: XCTestCase {

    private func sample(minute: Int, mm: Double, base: Date = Date()) -> RainSample {
        RainSample(minutesAhead: minute,
                   mmPerHour: mm,
                   validAt: base.addingTimeInterval(TimeInterval(minute * 60)))
    }

    func test_dryHorizon_endsActivity() {
        let base = Date()
        let rain = RainResponse(lat: 52.37, lon: 4.90, analysisAt: base,
                                samples: (0..<24).map { sample(minute: $0 * 5, mm: 0, base: base) })
        let plan = RainActivityPlan.from(rain: rain, weather: nil,
                                         thresholdMmPerHour: 0.1, horizonMinutes: 120)
        XCTAssertEqual(plan.action, .end)
        XCTAssertNil(plan.state.startsAt)
    }

    func test_rainStartsSoon_startsActivity() {
        let base = Date()
        var samples: [RainSample] = []
        for i in 0..<24 {
            samples.append(sample(minute: i * 5,
                                  mm: i >= 4 ? 2.0 : 0,
                                  base: base))
        }
        let rain = RainResponse(lat: 52.37, lon: 4.90, analysisAt: base, samples: samples)
        let plan = RainActivityPlan.from(rain: rain, weather: nil,
                                         thresholdMmPerHour: 0.1, horizonMinutes: 120)
        XCTAssertEqual(plan.action, .start)
        XCTAssertNotNil(plan.state.startsAt)
    }

    func test_rainAtEdgeOfHorizon_stillStarts() {
        let base = Date()
        var samples: [RainSample] = (0..<23).map { sample(minute: $0 * 5, mm: 0, base: base) }
        samples.append(sample(minute: 115, mm: 1.5, base: base))
        let rain = RainResponse(lat: 52.37, lon: 4.90, analysisAt: base, samples: samples)
        let plan = RainActivityPlan.from(rain: rain, weather: nil,
                                         thresholdMmPerHour: 0.1, horizonMinutes: 120)
        XCTAssertEqual(plan.action, .start)
        XCTAssertNotNil(plan.state.startsAt)
    }

    func test_intensitiesAreClamped() {
        let base = Date()
        let samples = (0..<24).map { sample(minute: $0 * 5, mm: 100, base: base) }
        let rain = RainResponse(lat: 52.37, lon: 4.90, analysisAt: base, samples: samples)
        let plan = RainActivityPlan.from(rain: rain, weather: nil,
                                         thresholdMmPerHour: 0.1, horizonMinutes: 120)
        for v in plan.state.intensities {
            XCTAssertLessThanOrEqual(v, 50)
        }
    }

    /// Regression for the stale-Live-Activity bug: with past observations
    /// in the payload, the plan must ignore them when picking startsAt.
    /// Pre-fix the activity locked onto a historical rain timestamp and
    /// the countdown clamped to "0 min" forever.
    func test_pastRain_isIgnoredForStartsAt() {
        let base = Date()
        var samples: [RainSample] = []
        // Past: it was raining 90 min ago.
        for i in -18 ..< 0 {
            samples.append(sample(minute: i * 5, mm: i >= -12 ? 2.0 : 0, base: base))
        }
        // Future: dry for the whole horizon.
        for i in 0 ..< 24 {
            samples.append(sample(minute: i * 5, mm: 0, base: base))
        }
        let rain = RainResponse(lat: 52.37, lon: 4.90, analysisAt: base, samples: samples)
        let plan = RainActivityPlan.from(rain: rain, weather: nil,
                                         thresholdMmPerHour: 0.1, horizonMinutes: 120)
        XCTAssertEqual(plan.action, .end)
        XCTAssertNil(plan.state.startsAt,
                     "Past rain must not become the activity's startsAt.")
    }

    func test_pastRain_doesNotMaskFutureStart() {
        let base = Date()
        var samples: [RainSample] = []
        // Past rain.
        for i in -18 ..< 0 {
            samples.append(sample(minute: i * 5, mm: 2.0, base: base))
        }
        // Future: dry briefly, then rain at +25 min.
        for i in 0 ..< 24 {
            samples.append(sample(minute: i * 5, mm: i >= 5 ? 2.0 : 0, base: base))
        }
        let rain = RainResponse(lat: 52.37, lon: 4.90, analysisAt: base, samples: samples)
        let plan = RainActivityPlan.from(rain: rain, weather: nil,
                                         thresholdMmPerHour: 0.1, horizonMinutes: 120)
        XCTAssertEqual(plan.action, .start)
        if let startsAt = plan.state.startsAt {
            XCTAssertGreaterThan(startsAt.timeIntervalSince(base), 0,
                                 "startsAt must be in the future.")
        } else {
            XCTFail("expected a future startsAt")
        }
    }
}

final class RainOutlookTests: XCTestCase {
    private func sample(minute: Int, mm: Double, base: Date) -> RainSample {
        RainSample(minutesAhead: minute,
                   mmPerHour: mm,
                   validAt: base.addingTimeInterval(TimeInterval(minute * 60)))
    }

    func test_dryNow_andDryAhead_returnsDry() {
        let base = Date()
        let samples = (-30...30).map { sample(minute: $0 * 5 / 5, mm: 0, base: base) }
        let rain = RainResponse(lat: 52.37, lon: 4.90, analysisAt: base, samples: samples)
        XCTAssertEqual(rain.outlook(now: base), .dry)
    }

    func test_dryNow_butRainSoon_returnsStartsSoon() {
        let base = Date()
        var samples: [RainSample] = []
        for i in -6...12 { samples.append(sample(minute: i * 5, mm: i >= 2 ? 2.0 : 0, base: base)) }
        let rain = RainResponse(lat: 52.37, lon: 4.90, analysisAt: base, samples: samples)
        if case .startsSoon(let at) = rain.outlook(now: base) {
            XCTAssertEqual(at.timeIntervalSince(base) / 60, 10, accuracy: 0.5)
        } else {
            XCTFail("expected .startsSoon")
        }
    }

    func test_rainingNow_butStopsSoon_returnsStopsSoon() {
        let base = Date()
        var samples: [RainSample] = []
        for i in -6...12 { samples.append(sample(minute: i * 5, mm: i < 1 ? 2.0 : 0, base: base)) }
        let rain = RainResponse(lat: 52.37, lon: 4.90, analysisAt: base, samples: samples)
        if case .stopsSoon = rain.outlook(now: base) { return }
        XCTFail("expected .stopsSoon")
    }

    func test_rainingNow_andContinuing_returnsRainingNow() {
        let base = Date()
        let samples = (-6...12).map { sample(minute: $0 * 5, mm: 2.0, base: base) }
        let rain = RainResponse(lat: 52.37, lon: 4.90, analysisAt: base, samples: samples)
        XCTAssertEqual(rain.outlook(now: base), .rainingNow)
    }
}
