import XCTest

/// Drives the app to capture App Store screenshots via fastlane's `snapshot`.
/// Run via:  bundle exec fastlane ios screenshots
///
/// Order matters: indices in the filename (01_, 02_, …) determine the order
/// shown on the App Store listing.
///
/// `@MainActor` is required because fastlane's `setupSnapshot`/`snapshot`
/// helpers are main-actor-isolated, and the project ships with
/// `SWIFT_STRICT_CONCURRENCY=complete`.
@MainActor
final class OpenWeerSnapshots: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
    }

    func test_capture_app_store_screenshots() throws {
        let app = XCUIApplication()

        // ---- 1. WELCOME ----
        let welcomeCTA = app.buttons["welcome.cta"]
        if welcomeCTA.waitForExistence(timeout: 6) {
            snapshot("01_welcome")
            welcomeCTA.tap()
        }

        // ---- LOCATION PERMISSION ----
        let locationSkip = app.buttons["location.skip"]
        if locationSkip.waitForExistence(timeout: 5) {
            locationSkip.tap()
        }

        // ---- PUSH PERMISSION ----
        let pushSkip = app.buttons["push.skip"]
        if pushSkip.waitForExistence(timeout: 5) {
            pushSkip.tap()
        }

        // ---- 2. MAIN — RADAR + RAIN CARD ----
        let amsterdamHeader = app.staticTexts["Amsterdam"]
        XCTAssertTrue(amsterdamHeader.waitForExistence(timeout: 15),
                      "Main view did not render — Amsterdam header missing")
        // Let the radar tiles finish loading so the hero shot looks polished.
        sleep(5)
        snapshot("02_radar_with_rain_card")

        // ---- 3. EXPANDED SHEET — 8-DAY FORECAST ----
        let handle = app.otherElements["sheet.handle"]
        if handle.waitForExistence(timeout: 5) {
            handle.tap()                       // medium → expanded
            sleep(1)
            let forecastHeader = app.staticTexts["8-daagse verwachting"]
            _ = forecastHeader.waitForExistence(timeout: 5)
            snapshot("03_eight_day_forecast")
        }

        // ---- 4. CHAT — STREAMING ANSWER ----
        // The chat button may live inside the expanded sheet or the header.
        let chatButton = app.buttons["chat.open"]
        if chatButton.waitForExistence(timeout: 5) {
            chatButton.tap()
            sleep(1)
            let suggestion = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'regenen'")
            ).firstMatch
            if suggestion.waitForExistence(timeout: 3) {
                suggestion.tap()
                // Let some tokens stream so the bubble has visible content.
                sleep(6)
                snapshot("04_chat_streaming")
            } else {
                snapshot("04_chat_empty")
            }
        }
    }
}
