//
//  BriefingTests.swift
//  CompassTests
//
//  Pulse's Apple Intelligence briefing may quote the app's figures, never new ones.
//

import Foundation
import Testing
@testable import Compass

private func fact(_ metric: Fact.Metric, _ value: Decimal, _ baseline: Decimal?, unit: Fact.Unit = .count) -> Fact {
    Fact(metric: metric, unit: unit, value: value, baseline: baseline, period: .lastSevenDays)
}

private let facts = [
    fact(.supporters, 48_312, 48_098),                                              // up 214
    fact(.newJoins, 386, 342),                                                      // up 13%
    fact(.raised, 23_480, 21_740, unit: .money(currencyCode: "USD")),               // up 8%
    fact(.averageGift, Decimal(string: "7.50")!, 8, unit: .money(currencyCode: "USD")),
    fact(.emailOpenRate, Decimal(string: "38.2")!, Decimal(string: "39.6")!, unit: .percent),  // down 1.4 pts
]

struct BriefingCheckTests {
    @Test func readsFiguresAsWritten() {
        #expect(BriefingCheck.numbers(in: "$23,480 and 38.2%, up 13%.") == [23_480, Decimal(string: "38.2")!, 13])
    }

    @Test func allowsTheAppsOwnFigures() {
        let text = "Great news: 386 people joined in the last 7 days, up 13%, and you raised $23,480. "
            + "Email opens dipped by 1.4 pts to 38.2%, while your average gift held at $7.50."
        #expect(BriefingCheck.isSafe(text, facts: facts))
    }

    @Test func rejectsAFigureTheModelWorkedOut() {
        // 23,480 − 21,740 = 1,740: true, but the app doesn't show it.
        #expect(!BriefingCheck.isSafe("You raised $1,740 more than the 7 days before.", facts: facts))
        #expect(!BriefingCheck.isSafe("Opens fell by 3.5%.", facts: facts))
    }

    @Test func rejectsSpelledOutNumbersAndWrongPeriods() {
        #expect(!BriefingCheck.isSafe("Giving fell by over a thousand dollars.", facts: facts))
        #expect(!BriefingCheck.isSafe("Great news today! You raised $23,480.", facts: facts))
        #expect(!BriefingCheck.isSafe("You raised $23,480 this week.", facts: facts))
    }

    @Test func checksSpelledOutSmallNumbers() {
        let nine = [fact(.supporters, 539_479, 539_470)]  // up 9
        #expect(BriefingCheck.isSafe("Nine more supporters joined your list in the last 7 days.", facts: nine))
        #expect(!BriefingCheck.isSafe("Eight more supporters joined your list in the last 7 days.", facts: nine))
    }

    @Test func rejectsSpeakingAsTheOrganization() {
        #expect(!BriefingCheck.isSafe("We raised $23,480 in the last 7 days.", facts: facts))
    }

    @Test func rejectsLongAnswers() {
        let long = Array(repeating: "Your supporters keep showing up.", count: 15).joined(separator: " ")
        #expect(!BriefingCheck.isSafe(long, facts: facts))
    }

    @Test func promptListsEveryFigure() {
        let prompt = BriefingWriter.prompt(for: facts)
        #expect(prompt.contains("New joins: 386 in the last 7 days, 342 in the 7 days before (up 13%)."))
        #expect(prompt.split(separator: "\n").count == facts.count + 1)
    }
}
