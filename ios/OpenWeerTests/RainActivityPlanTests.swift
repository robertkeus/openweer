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
