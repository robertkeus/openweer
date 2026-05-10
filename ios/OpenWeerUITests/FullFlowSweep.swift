import XCTest

/// Walks the entire app, attaching a screenshot at every screen so the run
/// produces a visual proof of all features. Live API at openweer.nl is used.
final class FullFlowSweep: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func test_sweep_all_screens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launch()

        attachScreenshot(named: "01_launch", app: app)

        // ---- WELCOME ----
        let welcomeCTA = app.buttons["welcome.cta"]
        if welcomeCTA.waitForExistence(timeout: 5) {
            attachScreenshot(named: "02_welcome", app: app)
            welcomeCTA.tap()
        }

        // ---- LOCATION ----
        let locationSkip = app.buttons["location.skip"]
        if locationSkip.waitForExistence(timeout: 5) {
            attachScreenshot(named: "03_location", app: app)
            locationSkip.tap()
        }

        // ---- PUSH ----
        let pushSkip = app.buttons["push.skip"]
        if pushSkip.waitForExistence(timeout: 5) {
            attachScreenshot(named: "04_push", app: app)
            pushSkip.tap()
        }

        // ---- MAIN VIEW ----
        let amsterdamHeader = app.staticTexts["Amsterdam"]
        XCTAssertTrue(amsterdamHeader.waitForExistence(timeout: 12),
                      "Main view did not render — Amsterdam header missing")
        sleep(4)
        attachScreenshot(named: "05_main_medium", app: app)

        // Verify rain card heading is present at medium detent
        let rainHeader = app.staticTexts["Regen — komende 2 uur"]
        XCTAssertTrue(rainHeader.waitForExistence(timeout: 8),
                      "Rain card header missing")

        // ---- TAP HANDLE → EXPANDED ----
        // Tapping the drag handle cycles detents: medium → expanded → collapsed → medium
        let handle = app.otherElements["sheet.handle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5), "Sheet handle missing")
        handle.tap()
        sleep(1)
        attachScreenshot(named: "06_sheet_expanded", app: app)

        // ---- TAP HANDLE → COLLAPSED ----
        handle.tap()
        sleep(1)
        attachScreenshot(named: "07_sheet_collapsed", app: app)

        // ---- DRAG HANDLE UP → BACK TO MEDIUM/EXPANDED ----
        let topCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: topCoord)
        sleep(1)
        attachScreenshot(named: "08_sheet_dragged_up", app: app)

        // ---- CHAT ----
        let chatButton = app.buttons["chat.open"]
        if chatButton.waitForExistence(timeout: 5) {
            chatButton.tap()
            sleep(1)
            attachScreenshot(named: "09_chat_empty", app: app)

            // Tap the first suggestion to send a real prompt + stream a response
            let suggestion = app.buttons.matching(
                NSPredicate(format: "label CONTAINS 'regenen'")
            ).firstMatch
            if suggestion.waitForExistence(timeout: 3) {
                suggestion.tap()
                sleep(6) // let some tokens stream in
                attachScreenshot(named: "10_chat_streaming", app: app)
            }
        }

        // Forecast list should be visible at expanded detent
        let forecastHeader = app.staticTexts["8-daagse verwachting"]
        XCTAssertTrue(forecastHeader.waitForExistence(timeout: 5),
                      "Forecast header missing at expanded detent")
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
