import XCTest

final class SearchSheetCapture: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func test_capture_search_sheet() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launch()

        // If onboarding shows up, dismiss it to land on Main.
        if app.buttons["welcome.cta"].waitForExistence(timeout: 3) {
            app.buttons["welcome.cta"].tap()
            if app.buttons["location.skip"].waitForExistence(timeout: 3) {
                app.buttons["location.skip"].tap()
            }
            if app.buttons["push.skip"].waitForExistence(timeout: 3) {
                app.buttons["push.skip"].tap()
            }
        }

        // Open the search sheet
        let searchOpen = app.buttons["location.search.open"]
        XCTAssertTrue(searchOpen.waitForExistence(timeout: 6))
        searchOpen.tap()
        sleep(1)
        attach("01_empty", app)

        // Type a query that returns results
        let field = app.textFields["location.search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Maa")
        sleep(2) // wait for debounce + Nominatim
        attach("02_results", app)
    }

    private func attach(_ name: String, _ app: XCUIApplication) {
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
