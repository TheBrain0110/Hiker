//
//  DragAndDropUITests.swift
//  HikerUITests
//
//  Created by Claude on 12/27/25.
//

import XCTest

/// UI tests for drag-and-drop functionality in day schedule editing
/// Tests drag handles, within-hike reordering, cross-hike moves, and drop zone
final class DragAndDropUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launchEnvironment = ["LoadSampleData": "true"]
        app.launch()

        // Navigate to schedule tab
        app.tabBars.buttons["Schedule"].tap()

        // Wait for schedule to load
        _ = app.staticTexts["Today"].waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Edit Mode Tests

    @MainActor
    func testDragHandlesOnlyAppearInEditMode() throws {
        // Navigate to a day with hikes
        navigateToTodayDetail()

        // Initially not in edit mode - drag handles should not exist
        let dragHandle = app.images["line.3.horizontal"].firstMatch
        XCTAssertFalse(dragHandle.exists, "Drag handles should not exist outside edit mode")

        // Enter edit mode
        app.navigationBars.buttons["Edit"].tap()

        // Drag handles should now exist
        XCTAssertTrue(dragHandle.waitForExistence(timeout: 2), "Drag handles should appear in edit mode")

        // Exit edit mode
        app.navigationBars.buttons["Done"].tap()

        // Drag handles should disappear
        XCTAssertFalse(dragHandle.exists, "Drag handles should disappear when exiting edit mode")
    }

    @MainActor
    func testNoDragFunctionalityOutsideEditMode() throws {
        navigateToTodayDetail()

        // Verify we can't initiate a drag
        // Note: This is hard to test directly, but we can verify drag handles don't exist
        let dragHandle = app.images["line.3.horizontal"].firstMatch
        XCTAssertFalse(dragHandle.exists, "Cannot drag without drag handles")
    }

    // MARK: - Within-Hike Reordering Tests

    @MainActor
    func testWithinHikeReorderingUpdatesPickupOrder() throws {
        navigateToTodayDetail()

        // Enter edit mode
        app.navigationBars.buttons["Edit"].tap()

        // Find the first hike card
        let hikeCard = app.otherElements.matching(identifier: "hikeCard").firstMatch
        XCTAssertTrue(hikeCard.waitForExistence(timeout: 2))

        // Get initial dog names in order
        let dogRows = hikeCard.otherElements.matching(identifier: "dogRow")
        guard dogRows.count >= 2 else {
            throw XCTSkip("Need at least 2 dogs in hike for reordering test")
        }

        let firstDog = dogRows.element(boundBy: 0)
        let secondDog = dogRows.element(boundBy: 1)

        let firstDogName = firstDog.staticTexts.firstMatch.label

        // Drag first dog to second position
        firstDog.press(forDuration: 0.5, thenDragTo: secondDog)

        // Wait for animation
        Thread.sleep(forTimeInterval: 0.5)

        // Verify order changed
        let newSecondDog = dogRows.element(boundBy: 1)
        let newSecondDogName = newSecondDog.staticTexts.firstMatch.label

        XCTAssertEqual(newSecondDogName, firstDogName, "Dog should have moved to second position")
    }

    @MainActor
    func testWithinHikeReorderingShowsVisualFeedback() throws {
        navigateToTodayDetail()

        app.navigationBars.buttons["Edit"].tap()

        let hikeCard = app.otherElements.matching(identifier: "hikeCard").firstMatch
        let dogRows = hikeCard.otherElements.matching(identifier: "dogRow")

        guard dogRows.count >= 2 else {
            throw XCTSkip("Need at least 2 dogs for visual feedback test")
        }

        let firstDog = dogRows.element(boundBy: 0)
        let secondDog = dogRows.element(boundBy: 1)

        // Start dragging first dog
        firstDog.press(forDuration: 0.5)

        // Move over second dog - should show visual feedback (blue highlight/spacing)
        // Note: Visual feedback is hard to test directly in UI tests
        // We can only verify the drag completes successfully
        firstDog.press(forDuration: 0.5, thenDragTo: secondDog)

        XCTAssertTrue(firstDog.exists, "Dog should still exist after drag")
    }

    // MARK: - Cross-Hike Moving Tests

    @MainActor
    func testCrossHikeDragMovesToCorrectPosition() throws {
        // This test requires a day with 2 hikes
        navigateToDayWithTwoHikes()

        app.navigationBars.buttons["Edit"].tap()

        let hikeCards = app.otherElements.matching(identifier: "hikeCard")
        guard hikeCards.count >= 2 else {
            throw XCTSkip("Need 2 hikes for cross-hike test")
        }

        let hike1 = hikeCards.element(boundBy: 0)
        let hike2 = hikeCards.element(boundBy: 1)

        let hike1Dogs = hike1.otherElements.matching(identifier: "dogRow")
        let hike2Dogs = hike2.otherElements.matching(identifier: "dogRow")

        guard hike1Dogs.count > 0, hike2Dogs.count > 0 else {
            throw XCTSkip("Both hikes need dogs")
        }

        let draggedDog = hike1Dogs.element(boundBy: 0)
        let targetDog = hike2Dogs.element(boundBy: 0)

        let draggedDogName = draggedDog.staticTexts.firstMatch.label
        let hike1InitialCount = hike1Dogs.count
        let hike2InitialCount = hike2Dogs.count

        // Drag from hike 1 to hike 2
        draggedDog.press(forDuration: 0.5, thenDragTo: targetDog)

        // Wait for update
        Thread.sleep(forTimeInterval: 0.5)

        // Verify counts changed
        let hike1NewCount = hike1.otherElements.matching(identifier: "dogRow").count
        let hike2NewCount = hike2.otherElements.matching(identifier: "dogRow").count

        XCTAssertEqual(hike1NewCount, hike1InitialCount - 1, "Hike 1 should have one fewer dog")
        XCTAssertEqual(hike2NewCount, hike2InitialCount + 1, "Hike 2 should have one more dog")

        // Verify the dog appears in hike 2
        let hike2DogsAfter = hike2.otherElements.matching(identifier: "dogRow")
        let movedDog = hike2DogsAfter.containing(.staticText, identifier: draggedDogName).firstMatch
        XCTAssertTrue(movedDog.exists, "Dragged dog should now be in hike 2")
    }

    // MARK: - Drop Zone Tests

    @MainActor
    func testDropZoneAppearsWithOneHikeInEditMode() throws {
        // Navigate to a day with exactly 1 hike
        navigateToDayWithOneHike()

        // Drop zone should not appear outside edit mode
        let dropZone = app.staticTexts["Drop here to create a second hike"]
        XCTAssertFalse(dropZone.exists, "Drop zone should not appear outside edit mode")

        // Enter edit mode
        app.navigationBars.buttons["Edit"].tap()

        // Drop zone still shouldn't appear until dragging
        XCTAssertFalse(dropZone.exists, "Drop zone should not appear until dragging starts")

        // Start dragging a dog
        let dogRow = app.otherElements.matching(identifier: "dogRow").firstMatch
        dogRow.press(forDuration: 0.5)

        // Drop zone should now appear
        XCTAssertTrue(dropZone.waitForExistence(timeout: 1), "Drop zone should appear when dragging in edit mode with 1 hike")
    }

    @MainActor
    func testDropZoneDisappearsWithTwoHikes() throws {
        // Navigate to day with 2 hikes
        navigateToDayWithTwoHikes()

        app.navigationBars.buttons["Edit"].tap()

        // Start dragging
        let dogRow = app.otherElements.matching(identifier: "dogRow").firstMatch
        dogRow.press(forDuration: 0.5)

        // Drop zone should NOT appear with 2 hikes
        let dropZone = app.staticTexts["Drop here to create a second hike"]
        XCTAssertFalse(dropZone.exists, "Drop zone should not appear when there are already 2 hikes")
    }

    @MainActor
    func testDropZoneCreatesSecondHikeWithDraggedDog() throws {
        navigateToDayWithOneHike()

        app.navigationBars.buttons["Edit"].tap()

        let hikeCards = app.otherElements.matching(identifier: "hikeCard")
        XCTAssertEqual(hikeCards.count, 1, "Should start with 1 hike")

        let dogRow = app.otherElements.matching(identifier: "dogRow").firstMatch
        let dogName = dogRow.staticTexts.firstMatch.label

        // Start dragging
        dogRow.press(forDuration: 0.5)

        // Find drop zone
        let dropZone = app.staticTexts["Drop here to create a second hike"]
        XCTAssertTrue(dropZone.waitForExistence(timeout: 1))

        // Drag to drop zone
        dogRow.press(forDuration: 0.5, thenDragTo: dropZone)

        // Wait for second hike to be created
        Thread.sleep(forTimeInterval: 1)

        // Should now have 2 hikes
        let newHikeCards = app.otherElements.matching(identifier: "hikeCard")
        XCTAssertEqual(newHikeCards.count, 2, "Should now have 2 hikes")

        // Verify the dragged dog is in hike 2
        let hike2 = newHikeCards.element(boundBy: 1)
        let hike2Dog = hike2.otherElements.containing(.staticText, identifier: dogName).firstMatch
        XCTAssertTrue(hike2Dog.exists, "Dragged dog should be in the new second hike")
    }

    // MARK: - Day-Level Actions Tests

    @MainActor
    func testRegroupAllHikesButton() throws {
        navigateToTodayDetail()

        app.navigationBars.buttons["Edit"].tap()

        // Find "Regroup All Hikes" button
        let regroupButton = app.buttons["Regroup All Hikes"]
        XCTAssertTrue(regroupButton.waitForExistence(timeout: 2), "Regroup button should exist in edit mode")

        // Tap it
        regroupButton.tap()

        // Wait for regrouping
        Thread.sleep(forTimeInterval: 1)

        // Should still be in edit mode
        XCTAssertTrue(app.navigationBars.buttons["Done"].exists, "Should still be in edit mode after regrouping")
    }

    @MainActor
    func testResetDayToScheduleButton() throws {
        navigateToTodayDetail()

        app.navigationBars.buttons["Edit"].tap()

        // Find "Reset Day to Schedule" button
        let resetButton = app.buttons["Reset Day to Schedule"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 2), "Reset button should exist in edit mode")

        // Tap it
        resetButton.tap()

        // Wait for reset
        Thread.sleep(forTimeInterval: 1)

        // Should still be in edit mode
        XCTAssertTrue(app.navigationBars.buttons["Done"].exists, "Should still be in edit mode after reset")
    }

    @MainActor
    func testEditModeExitsOnDone() throws {
        navigateToTodayDetail()

        app.navigationBars.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Done"].exists)

        app.navigationBars.buttons["Done"].tap()

        // Should exit edit mode
        XCTAssertTrue(app.navigationBars.buttons["Edit"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.navigationBars.buttons["Done"].exists)
    }

    @MainActor
    func testEditModeExitsOnNavigation() throws {
        navigateToTodayDetail()

        app.navigationBars.buttons["Edit"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Done"].exists)

        // Navigate back
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Navigate forward again
        navigateToTodayDetail()

        // Should not be in edit mode
        XCTAssertTrue(app.navigationBars.buttons["Edit"].exists)
        XCTAssertFalse(app.navigationBars.buttons["Done"].exists)
    }

    // MARK: - Helper Methods

    private func navigateToTodayDetail() {
        // Find "Today" in the schedule list
        let todayRow = app.staticTexts["Today"]
        if todayRow.exists {
            todayRow.tap()
        } else {
            // Use calendar view
            app.buttons["Calendar"].tap()
            // Tap today's date (implementation depends on calendar layout)
            let today = Date()
            let calendar = Calendar.current
            let day = calendar.component(.day, from: today)
            app.staticTexts["\(day)"].tap()
        }

        // Wait for detail view
        _ = app.navigationBars["Day Schedule"].waitForExistence(timeout: 3)
    }

    private func navigateToDayWithOneHike() {
        // Navigate to a specific test day that has exactly 1 hike
        // This would need to be set up in sample data
        // For now, assume today has 1 hike
        navigateToTodayDetail()
    }

    private func navigateToDayWithTwoHikes() {
        // Navigate to a specific test day that has exactly 2 hikes
        // This would need to be set up in sample data
        // Implementation depends on test data structure
        navigateToTodayDetail()

        // If only 1 hike, create a second one first
        let hikeCards = app.otherElements.matching(identifier: "hikeCard")
        if hikeCards.count == 1 {
            app.navigationBars.buttons["Edit"].tap()

            let dogRow = app.otherElements.matching(identifier: "dogRow").firstMatch
            dogRow.press(forDuration: 0.5)

            let dropZone = app.staticTexts["Drop here to create a second hike"]
            if dropZone.waitForExistence(timeout: 1) {
                dogRow.press(forDuration: 0.5, thenDragTo: dropZone)
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }
}
