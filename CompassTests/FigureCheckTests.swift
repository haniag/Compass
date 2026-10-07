//
//  FigureCheckTests.swift
//  CompassTests
//
//  Quantity words ("half", "doubled", "fifty percent") pass only when they match
//  a figure the app shows.
//

import Foundation
import Testing
@testable import Compass

private func fact(_ metric: Fact.Metric, _ value: Decimal, _ baseline: Decimal?, unit: Fact.Unit = .count) -> Fact {
    Fact(metric: metric, unit: unit, value: value, baseline: baseline, period: .lastSevenDays)
}

struct FigureCheckTests {
    private let joinsHalved = fact(.newJoins, 4, 8)    // down 50%
    private let joinsDown30 = fact(.newJoins, 7, 10)   // down 30%
    private let joinsDoubled = fact(.newJoins, 20, 10) // up 100%

    private func passes(_ text: String, _ facts: Fact...) -> Bool {
        FigureCheck.quotesOnlyFigures(of: facts, in: text)
    }

    @Test func halfPassesWhenTheFigureFellFiftyPercent() {
        #expect(passes("New members fell by half", joinsHalved))
        #expect(passes("New joins halved, from 8 to 4 in the last 7 days.", joinsHalved))
    }

    @Test func halfFailsWhenItDidnt() {
        #expect(!passes("New members fell by half", joinsDown30))
        #expect(!passes("New members fell by half", joinsDoubled))
    }

    @Test func doublePassesOnlyWhenTheFigureRoseAHundredPercent() {
        #expect(passes("New joins doubled in the last 7 days.", joinsDoubled))
        #expect(passes("Twice as many people joined.", joinsDoubled))
        #expect(!passes("New joins doubled in the last 7 days.", joinsHalved))
    }

    @Test func spelledPercentPassesWhenItMatches() {
        #expect(passes("New joins dropped from eight to four, down fifty percent.", joinsHalved))
        #expect(passes("New joins fell 50 percent.", joinsHalved))
        #expect(!passes("New joins fell forty percent.", joinsHalved))
    }

    @Test func percentWithoutANumberFails() {
        #expect(!passes("Sign-ups fell by a few percent.", joinsHalved))
    }

    @Test func otherAmountsInWordsStillFail() {
        #expect(!passes("Giving fell by over a thousand dollars.", joinsHalved))
        #expect(!passes("A third fewer people joined.", joinsHalved))
    }

    @Test func weekStillFailsEvenWhenTheFigureIsRight() {
        #expect(!passes("Four new supporters joined in the last week.", joinsHalved))
    }

    @Test func periodWordsFollowTheFacts() {
        let yesterday = Fact(metric: .newJoins, unit: .count, value: 20, baseline: 10, period: .yesterday)
        let thirty = Fact(metric: .newJoins, unit: .count, value: 20, baseline: 10, period: .lastThirtyDays)
        // "yesterday" is right for yesterday's figures only.
        #expect(passes("20 people joined yesterday.", yesterday))
        #expect(!passes("20 people joined yesterday.", fact(.newJoins, 20, 10)))
        #expect(!passes("20 people joined today.", yesterday))
        // The 30 in "last 30 days" isn't a made-up figure, but 7 is when the period is 30 days.
        #expect(passes("20 people joined in the last 30 days.", thirty))
        #expect(!passes("20 people joined in the last 7 days.", thirty))
    }

    @Test func monthWordsOnlyForLastMonth() {
        let lastMonth = Fact(metric: .emailOpenRate, unit: .percent, value: Decimal(string: "85.7")!, baseline: 100, period: .lastMonth)
        #expect(passes("Email opens fell to 85.7% last month, from 100.0% the month before.", lastMonth))
        // The month the figures cover is over, so it's never "this month".
        #expect(!passes("Email opens fell from 100.0% last month to 85.7% this month.", lastMonth))
        #expect(!passes("New joins fell this month.", fact(.newJoins, 7, 10)))
    }
}
