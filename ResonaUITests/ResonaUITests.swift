import XCTest

final class ResonaUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyLibraryExplainsOfflineImportAndOffersChooseFiles() {
        let app = launchApp(scenario: "--ui-testing-empty-library")

        XCTAssertTrue(app.staticTexts["No Songs"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts[
                "Choose audio files to copy them into Resona for offline listening."
            ].exists
        )
        XCTAssertTrue(app.buttons["library.chooseFiles"].exists)
    }

    @MainActor
    func testPersistedLibraryShowsFallbackAndUnavailableStatus() {
        let app = launchApp(scenario: "--ui-testing-populated-library")

        let aerialLines = app.descendants(matching: .any)[
            "library.song.00000000-0000-0000-0000-000000000001"
        ]
        let fallback = app.descendants(matching: .any)[
            "library.song.00000000-0000-0000-0000-000000000002"
        ]
        let unavailable = app.descendants(matching: .any)[
            "library.song.00000000-0000-0000-0000-000000000003"
        ]
        XCTAssertTrue(aerialLines.waitForExistence(timeout: 5))
        XCTAssertTrue(fallback.exists)
        XCTAssertTrue(fallback.label.contains("Filename Fallback"))
        XCTAssertTrue(fallback.label.contains("Unknown Artist"))
        XCTAssertTrue(unavailable.exists)
        XCTAssertTrue(unavailable.label.contains("Missing Resource"))
        XCTAssertTrue(unavailable.label.contains("Unavailable"))
        XCTAssertFalse(app.buttons["Aerial Lines"].exists)
        XCTAssertFalse(app.buttons["Missing Resource"].exists)
    }

    @MainActor
    func testImportProgressCancellationAndPerFileRecovery() {
        let app = launchApp(scenario: "--ui-testing-import-session")

        XCTAssertTrue(
            app.staticTexts["3 of 4 files completed"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Importing Cancelled.aiff"].exists)

        let cancel = app.buttons["import.cancel"]
        XCTAssertTrue(cancel.exists)
        cancel.tap()

        XCTAssertTrue(app.buttons["import.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Retry Me.wav"].exists)
        XCTAssertTrue(app.buttons["import.retry.2"].exists)
        XCTAssertTrue(app.buttons["import.chooseFiles.2"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Cancelled.aiff"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["import.chooseFiles.3"].exists)

        app.swipeDown()
        app.buttons["import.retry.2"].tap()
        XCTAssertTrue(app.staticTexts["Imported into your library."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["import.done"].exists)
    }

    @MainActor
    func testEmptyLibraryAtAccessibilityTextSizeKeepsPrimaryActionVisible() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing-empty-library",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["library.chooseFiles"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["library.chooseFiles"].isHittable)
    }

    @MainActor
    private func launchApp(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [scenario]
        app.launch()
        return app
    }
}
