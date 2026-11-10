//
//  CompassSmokeTests.swift
//  CompassUITests
//
//  Opens the app in demo mode (fake data, no network, see DebugUITestDemo) and visits
//  every tab, to catch a screen that crashes or comes up empty.
//

import XCTest

final class CompassSmokeTests: XCTestCase {
    private let timeout: TimeInterval = 20

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testEveryTabShowsDemoNumbers() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestDemo"]
        app.launch()

        // Pulse
        XCTAssertTrue(app.staticTexts["Pulse"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Supporters"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["Share these numbers"].exists)

        // Insights
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["Insights"].waitForExistence(timeout: timeout))

        // Giving: the page's numbers, its goal, and all pages together
        app.tabBars.buttons["Giving"].tap()
        XCTAssertTrue(app.staticTexts["Giving"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Goal"].waitForExistence(timeout: timeout))
        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["All pages"].waitForExistence(timeout: timeout))

        // Email
        app.tabBars.buttons["Email"].tap()
        XCTAssertTrue(app.staticTexts["Recent sends"].waitForExistence(timeout: timeout))

        // More
        app.tabBars.buttons["More"].tap()
        XCTAssertTrue(app.switches["Alerts"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["Disconnect"].exists)
    }
}
