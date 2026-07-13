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
        XCTAssertTrue(
            app.buttons[
                "library.song.00000000-0000-0000-0000-000000000001"
            ].exists
        )
        XCTAssertFalse(app.buttons["Missing Resource"].exists)
    }

    @MainActor
    func testSelectingSongControlsPlaybackWithoutSheetSideEffects() {
        let app = launchApp(scenario: "--ui-testing-populated-library")
        let song = app.buttons[
            "library.song.00000000-0000-0000-0000-000000000001"
        ]
        XCTAssertTrue(song.waitForExistence(timeout: 5))
        song.tap()

        let openPlayer = app.buttons["playback.currentSong.open"]
        let currentTransport = app.buttons["playback.currentSong.transport"]
        XCTAssertTrue(openPlayer.waitForExistence(timeout: 5))
        XCTAssertEqual(currentTransport.label, "Pause")

        openPlayer.tap()
        let playerTransport = app.buttons["player.transport"]
        XCTAssertTrue(playerTransport.waitForExistence(timeout: 5))
        XCTAssertEqual(playerTransport.label, "Pause")
        app.buttons["player.done"].tap()

        XCTAssertTrue(currentTransport.waitForExistence(timeout: 5))
        XCTAssertEqual(currentTransport.label, "Pause")
        currentTransport.tap()
        waitForLabel("Play", on: currentTransport)

        openPlayer.tap()
        XCTAssertTrue(playerTransport.waitForExistence(timeout: 5))
        XCTAssertEqual(playerTransport.label, "Play")
        playerTransport.tap()
        waitForLabel("Pause", on: playerTransport)
    }

    @MainActor
    func testPlaybackFailuresExposeTypedRecovery() {
        let resourceApp = launchApp(
            scenario: "--ui-testing-playback-resource-failure"
        )
        let resourceOpen = resourceApp.buttons["playback.currentSong.open"]
        XCTAssertTrue(resourceOpen.waitForExistence(timeout: 5))
        resourceOpen.tap()
        XCTAssertTrue(resourceApp.buttons["player.reimport"].waitForExistence(timeout: 5))
        resourceApp.terminate()

        let transientApp = launchApp(
            scenario: "--ui-testing-playback-transient-failure"
        )
        let transientOpen = transientApp.buttons["playback.currentSong.open"]
        XCTAssertTrue(transientOpen.waitForExistence(timeout: 5))
        transientOpen.tap()
        let retry = transientApp.buttons["player.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()
        let transport = transientApp.buttons["player.transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 5))
        XCTAssertEqual(transport.label, "Pause")
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
        let cancelledFile = app.staticTexts["Cancelled.aiff"]
        for _ in 0..<3 where !cancelledFile.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(cancelledFile.waitForExistence(timeout: 5))
        XCTAssertTrue(cancelledFile.isHittable)
        XCTAssertTrue(app.buttons["import.chooseFiles.3"].exists)

        let retry = app.buttons["import.retry.2"]
        for _ in 0..<3 where !retry.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(retry.isHittable)
        retry.tap()
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
    func testCurrentSongControlsRemainUsableAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing-populated-library",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        let song = app.buttons[
            "library.song.00000000-0000-0000-0000-000000000001"
        ]
        XCTAssertTrue(song.waitForExistence(timeout: 5))
        song.tap()
        let openPlayer = app.buttons["playback.currentSong.open"]
        let transport = app.buttons["playback.currentSong.transport"]
        XCTAssertTrue(openPlayer.waitForExistence(timeout: 5))
        XCTAssertTrue(openPlayer.isHittable)
        XCTAssertTrue(transport.isHittable)
    }

    @MainActor
    private func waitForLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval = 5
    ) {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )

        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed
        )
    }

    @MainActor
    private func launchApp(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [scenario]
        app.launch()
        return app
    }
}
