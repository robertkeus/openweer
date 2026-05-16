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
