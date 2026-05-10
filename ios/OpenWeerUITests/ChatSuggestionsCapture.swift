import XCTest

final class ChatSuggestionsCapture: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func test_capture_chat_shortcuts() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(nl)", "-AppleLocale", "nl_NL"]
        app.launch()

        if app.buttons["welcome.cta"].waitForExistence(timeout: 3) {
            app.buttons["welcome.cta"].tap()
            if app.buttons["location.skip"].waitForExistence(timeout: 3) {
                app.buttons["location.skip"].tap()
            }
            if app.buttons["push.skip"].waitForExistence(timeout: 3) {
                app.buttons["push.skip"].tap()
            }
        }

        let chatBtn = app.buttons["chat.open"]
        XCTAssertTrue(chatBtn.waitForExistence(timeout: 8))
        chatBtn.tap()
        sleep(1)
        let s = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: s)
        a.name = "chat_shortcuts"
        a.lifetime = .keepAlways
        add(a)
    }
}
