import XCTest
@testable import OpenWeer

final class WidgetRefreshPolicyTests: XCTestCase {
    func test_rainCadence() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let next = WidgetRefreshPolicy.nextReload(now: now, kind: .rain)
        XCTAssertEqual(next.timeIntervalSince(now), 10 * 60, accuracy: 0.1)
    }

    func test_currentCadence() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let next = WidgetRefreshPolicy.nextReload(now: now, kind: .current)
        XCTAssertEqual(next.timeIntervalSince(now), 20 * 60, accuracy: 0.1)
    }

    func test_forecastCadence() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let next = WidgetRefreshPolicy.nextReload(now: now, kind: .forecast)
        XCTAssertEqual(next.timeIntervalSince(now), 60 * 60, accuracy: 0.1)
    }
}

final class RainBarChartHeightTests: XCTestCase {
    func test_zeroMmPerHourIsZero() {
        XCTAssertEqual(RainBarChart.height(forMmPerHour: 0, full: 100), 0, accuracy: 0.01)
    }

    func test_clampsAtTwentyMm() {
        let h20 = RainBarChart.height(forMmPerHour: 20, full: 100)
        let h100 = RainBarChart.height(forMmPerHour: 100, full: 100)
        XCTAssertEqual(h20, h100, accuracy: 0.01)
        XCTAssertEqual(h20, 100, accuracy: 0.01)
    }

    func test_squareRootCurve() {
        let h1 = RainBarChart.height(forMmPerHour: 1, full: 100)
        let h4 = RainBarChart.height(forMmPerHour: 4, full: 100)
        // 4 mm/h should reach twice the height of 1 mm/h (sqrt curve).
        XCTAssertEqual(h4, h1 * 2, accuracy: 0.5)
    }
}
