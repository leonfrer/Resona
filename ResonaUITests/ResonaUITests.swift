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
        let currentPrevious = app.buttons["playback.currentSong.previous"]
        let currentNext = app.buttons["playback.currentSong.next"]
        XCTAssertTrue(openPlayer.waitForExistence(timeout: 5))
        XCTAssertEqual(currentTransport.label, "Pause")
        XCTAssertFalse(currentPrevious.isEnabled)
        XCTAssertTrue(currentNext.isEnabled)
        XCTAssertFalse(app.staticTexts["Playing"].exists)

        openPlayer.tap()
        let playerTransport = app.buttons["player.transport"]
        XCTAssertTrue(playerTransport.waitForExistence(timeout: 5))
        XCTAssertEqual(playerTransport.label, "Pause")
        XCTAssertFalse(app.buttons["player.done"].exists)
        XCTAssertFalse(app.staticTexts["Playing"].exists)

        app.swipeDown()

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
    func testPlayerExposesQueueModesAndNavigation() {
        let app = launchApp(scenario: "--ui-testing-populated-library")
        let song = app.buttons[
            "library.song.00000000-0000-0000-0000-000000000001"
        ]
        XCTAssertTrue(song.waitForExistence(timeout: 5))
        song.tap()
        app.buttons["playback.currentSong.open"].tap()

        let previous = app.buttons["player.previous"]
        let next = app.buttons["player.next"]
        let queue = app.buttons["player.queue.open"]
        XCTAssertTrue(queue.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["player.shuffle"].exists)
        queue.tap()

        let shuffle = app.buttons["player.shuffle"]
        let repeatMode = app.buttons["player.repeat"]
        XCTAssertTrue(shuffle.waitForExistence(timeout: 5))
        XCTAssertEqual(shuffle.label, "Shuffle Off")
        XCTAssertEqual(repeatMode.label, "Repeat Off")

        XCTAssertTrue(
            app.descendants(matching: .any)[
                "player.queue.item.00000000-0000-0000-0000-000000000001"
            ].waitForExistence(timeout: 5)
        )

        shuffle.tap()
        waitForLabel("Shuffle On", on: shuffle)
        repeatMode.tap()
        waitForLabel("Repeat All", on: repeatMode)

        let unavailableQueueItem = app.descendants(matching: .any)[
            "player.queue.item.00000000-0000-0000-0000-000000000003"
        ]
        for _ in 0..<3 where !unavailableQueueItem.exists {
            app.swipeUp()
        }
        XCTAssertTrue(unavailableQueueItem.waitForExistence(timeout: 5))
        XCTAssertTrue(unavailableQueueItem.label.contains("Unavailable"))

        shuffle.tap()
        waitForLabel("Shuffle Off", on: shuffle)

        let sheetDragStart = app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.52)
        )
        let sheetDragEnd = app.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)
        )
        sheetDragStart.press(forDuration: 0.1, thenDragTo: sheetDragEnd)
        XCTAssertTrue(shuffle.waitForNonExistence(timeout: 5))
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertTrue(previous.exists)
        XCTAssertTrue(previous.isEnabled)
        XCTAssertTrue(next.isEnabled)

        next.tap()
        XCTAssertTrue(app.staticTexts["Filename Fallback"].waitForExistence(timeout: 5))
        XCTAssertTrue(previous.isEnabled)
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
    func testRestorationLaunchesPausedWithoutAudiblePlaybackIntent() {
        let app = launchApp(scenario: "--ui-testing-playback-restoration")
        let openPlayer = app.buttons["playback.currentSong.open"]
        XCTAssertTrue(openPlayer.waitForExistence(timeout: 5))
        XCTAssertTrue(openPlayer.label.contains("Aerial Lines"))

        openPlayer.tap()
        let transport = app.buttons["player.transport"]
        XCTAssertTrue(transport.waitForExistence(timeout: 5))
        XCTAssertEqual(transport.label, "Play")
        XCTAssertEqual(app.staticTexts["0:30"].label, "0:30")
    }

    @MainActor
    func testScrubberTapKeepsPositionAndDragStartsFromCurrentPosition() {
        let app = launchApp(scenario: "--ui-testing-playback-restoration")
        let openPlayer = app.buttons["playback.currentSong.open"]
        XCTAssertTrue(openPlayer.waitForExistence(timeout: 5))
        openPlayer.tap()

        let scrubber = app.otherElements["Playback Position"]
        XCTAssertTrue(scrubber.waitForExistence(timeout: 5))
        XCTAssertEqual(scrubber.value as? String, "0:30")

        scrubber.coordinate(
            withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)
        ).tap()

        XCTAssertEqual(scrubber.value as? String, "0:30")

        let dragStart = scrubber.coordinate(
            withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)
        )
        let dragEnd = scrubber.coordinate(
            withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)
        )
        dragStart.press(forDuration: 0.2, thenDragTo: dragEnd)

        XCTAssertEqual(scrubber.value as? String, "0:51")
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
        let next = app.buttons["playback.currentSong.next"]
        XCTAssertTrue(openPlayer.waitForExistence(timeout: 5))
        XCTAssertTrue(openPlayer.isHittable)
        XCTAssertTrue(transport.isHittable)
        XCTAssertTrue(next.isHittable)

        openPlayer.tap()
        let playerTransport = app.buttons["player.transport"]
        let queue = app.buttons["player.queue.open"]
        XCTAssertTrue(playerTransport.waitForExistence(timeout: 5))
        XCTAssertTrue(playerTransport.isHittable)
        XCTAssertTrue(queue.isHittable)
    }

    @MainActor
    func testRemovalRecoveryActionsRemainDiscoverableAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing-populated-library",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        let unavailable = app.descendants(matching: .any)[
            "library.song.00000000-0000-0000-0000-000000000003"
        ]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 5))
        unavailable.swipeLeft()

        let reimport = app.buttons[
            "library.reimport.00000000-0000-0000-0000-000000000003"
        ]
        let remove = app.buttons[
            "library.remove.00000000-0000-0000-0000-000000000003"
        ]
        XCTAssertTrue(reimport.waitForExistence(timeout: 5))
        XCTAssertTrue(reimport.isHittable)
        XCTAssertTrue(remove.isHittable)
        remove.tap()

        let confirmation = app.alerts["Remove “Missing Resource”?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(confirmation.buttons["Cancel"].isHittable)
        XCTAssertTrue(confirmation.buttons["Remove"].isHittable)
        confirmation.buttons["Cancel"].tap()
        app.terminate()

        let cleanupApp = XCUIApplication()
        cleanupApp.launchArguments = [
            "--ui-testing-removal-cleanup-failure",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        cleanupApp.launch()
        let song = cleanupApp.buttons[
            "library.song.00000000-0000-0000-0000-000000000001"
        ]
        XCTAssertTrue(song.waitForExistence(timeout: 5))
        revealRemoveAction(
            for: song,
            songID: "00000000-0000-0000-0000-000000000001",
            in: cleanupApp
        ).tap()
        cleanupApp.alerts["Remove “Aerial Lines”?"].buttons["Remove"].tap()

        let cleanupAlert = cleanupApp.alerts["Cleanup Couldn’t Finish"]
        XCTAssertTrue(cleanupAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(cleanupAlert.buttons["Try Again"].isHittable)
    }

    @MainActor
    func testRemovingNonCurrentSongRequiresConfirmationAndPreservesPlayback() {
        let app = launchApp(scenario: "--ui-testing-populated-library")
        let current = app.buttons[
            "library.song.00000000-0000-0000-0000-000000000001"
        ]
        let removed = app.buttons[
            "library.song.00000000-0000-0000-0000-000000000002"
        ]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        current.tap()
        XCTAssertTrue(
            app.buttons["playback.currentSong.open"].waitForExistence(timeout: 5)
        )

        revealRemoveAction(
            for: removed,
            songID: "00000000-0000-0000-0000-000000000002",
            in: app
        ).tap()
        let alert = app.alerts["Remove “Filename Fallback”?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertFalse(
            alert.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "Playback will stop")
            ).firstMatch.exists
        )

        alert.buttons["Cancel"].tap()
        XCTAssertTrue(removed.exists)
        XCTAssertTrue(app.buttons["playback.currentSong.open"].exists)

        revealRemoveAction(
            for: removed,
            songID: "00000000-0000-0000-0000-000000000002",
            in: app
        ).tap()
        app.alerts["Remove “Filename Fallback”?"].buttons["Remove"].tap()

        XCTAssertTrue(removed.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["playback.currentSong.open"].exists)
    }

    @MainActor
    func testRemovingCurrentSongStopsPlaybackAndClearsCurrentSurface() {
        let app = launchApp(scenario: "--ui-testing-populated-library")
        let current = app.buttons[
            "library.song.00000000-0000-0000-0000-000000000001"
        ]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        current.tap()
        XCTAssertTrue(
            app.buttons["playback.currentSong.open"].waitForExistence(timeout: 5)
        )

        revealRemoveAction(
            for: current,
            songID: "00000000-0000-0000-0000-000000000001",
            in: app
        ).tap()
        let alert = app.alerts["Remove “Aerial Lines”?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(
            alert.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "Playback will stop")
            ).firstMatch.exists
        )
        alert.buttons["Remove"].tap()

        XCTAssertTrue(current.waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["playback.currentSong.open"].waitForNonExistence(
                timeout: 5
            )
        )
    }

    @MainActor
    func testUnavailableSongExposesReimportAndRemoveActions() {
        let app = launchApp(scenario: "--ui-testing-populated-library")
        let unavailable = app.descendants(matching: .any)[
            "library.song.00000000-0000-0000-0000-000000000003"
        ]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 5))

        unavailable.swipeLeft()

        XCTAssertTrue(
            app.buttons[
                "library.reimport.00000000-0000-0000-0000-000000000003"
            ].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.buttons[
                "library.remove.00000000-0000-0000-0000-000000000003"
            ].exists
        )
    }

    @MainActor
    func testRemovingFinalSongReturnsToOfflineEmptyState() {
        let app = launchApp(scenario: "--ui-testing-removal-final-song")
        let song = app.buttons[
            "library.song.00000000-0000-0000-0000-000000000001"
        ]
        XCTAssertTrue(song.waitForExistence(timeout: 5))

        revealRemoveAction(
            for: song,
            songID: "00000000-0000-0000-0000-000000000001",
            in: app
        ).tap()
        app.alerts["Remove “Aerial Lines”?"].buttons["Remove"].tap()

        XCTAssertTrue(app.staticTexts["No Songs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["library.chooseFiles"].exists)
    }

    @MainActor
    func testRemovalConfirmationDoesNotExposeInternalUUIDTitle() {
        let app = launchApp(
            scenario: "--ui-testing-removal-identifier-title"
        )
        let identifier = "00000000-0000-0000-0000-000000000004"
        let song = app.buttons["library.song.\(identifier)"]
        XCTAssertTrue(song.waitForExistence(timeout: 5))

        revealRemoveAction(
            for: song,
            songID: identifier,
            in: app
        ).tap()

        let alert = app.alerts["Remove “Unknown Title”?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(song.exists)
        XCTAssertFalse(
            alert.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", identifier)
            ).firstMatch.exists
        )
    }

    @MainActor
    func testCleanupFailureKeepsSongAbsentAndTryAgainCompletes() {
        let app = launchApp(
            scenario: "--ui-testing-removal-cleanup-failure"
        )
        let song = app.buttons[
            "library.song.00000000-0000-0000-0000-000000000001"
        ]
        XCTAssertTrue(song.waitForExistence(timeout: 5))

        revealRemoveAction(
            for: song,
            songID: "00000000-0000-0000-0000-000000000001",
            in: app
        ).tap()
        app.alerts["Remove “Aerial Lines”?"].buttons["Remove"].tap()

        let cleanupAlert = app.alerts["Cleanup Couldn’t Finish"]
        XCTAssertTrue(cleanupAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(song.waitForNonExistence(timeout: 5))
        cleanupAlert.buttons["Try Again"].tap()

        XCTAssertTrue(cleanupAlert.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No Songs"].exists)
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
    private func revealRemoveAction(
        for song: XCUIElement,
        songID: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        song.swipeLeft()
        let remove = app.buttons["library.remove.\(songID)"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        return remove
    }

    @MainActor
    private func launchApp(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [scenario]
        app.launch()
        return app
    }
}
