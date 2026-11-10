//
//  AlertsTests.swift
//  CompassTests
//
//  Which findings become notifications, and that each is announced once.
//

import Foundation
import Testing
@testable import Compass

struct AlertsTests {
    @Test func listFatigueIsTiedToTheNewestSend() {
        let fatigue = EmailStats.Fatigue(sends: 3, timesUsual: 4)
        let alert = Alerts.listFatigue(fatigue, newestSendId: 812)
        #expect(alert?.id == "fatigue.812")
        #expect(alert?.body.contains("last 3 emails") == true)
        #expect(alert?.body.contains("about 4 times") == true)
        #expect(Alerts.listFatigue(nil, newestSendId: 812) == nil)
        #expect(Alerts.listFatigue(fatigue, newestSendId: nil) == nil)
    }

    @Test func goalReachedOnlyOnceRaisedMeetsTheGoal() {
        #expect(Alerts.goalReached(pageId: 7, pageName: "Fall Appeal", goal: 10_000, raised: 9_999, currency: "USD") == nil)
        let alert = Alerts.goalReached(pageId: 7, pageName: "Fall Appeal", goal: 10_000, raised: 10_250, currency: "USD")
        #expect(alert?.id == "goal.7.10000")
        #expect(alert?.body.hasPrefix("Fall Appeal has raised") == true)
    }

    @Test func aNewGoalForTheSamePageCanBeAnnouncedAgain() {
        let first = Alerts.goalReached(pageId: 7, pageName: "Fall Appeal", goal: 10_000, raised: 20_000, currency: "USD")
        let second = Alerts.goalReached(pageId: 7, pageName: "Fall Appeal", goal: 15_000, raised: 20_000, currency: "USD")
        #expect(first?.id != second?.id)
    }

    @Test func alertsAlreadySentAreLeftOut() {
        let old = Alerts.Alert(id: "fatigue.1", title: "", body: "")
        let new = Alerts.Alert(id: "fatigue.2", title: "", body: "")
        #expect(Alerts.notYetSent([old, new], sent: ["fatigue.1"]) == [new])
    }
}
