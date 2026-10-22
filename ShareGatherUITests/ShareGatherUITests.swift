import XCTest

/// UI-level checks for visible ShareGather behavior.
final class ShareGatherUITests: XCTestCase {
    /// Confirms launch reaches the app's home navigation surface.
    @MainActor
    func testHomeScreenDisplaysApplicationTitle() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["ShareGather"].waitForExistence(timeout: 5))
    }
}
