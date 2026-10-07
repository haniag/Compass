//
//  InsightTests.swift
//  CompassTests
//
//  Which changes get highlighted, how template insights are written, and how
//  the on-device model's drafts are checked.
//

import Foundation
import Testing
@testable import Compass

private func fact(_ metric: Fact.Metric, _ value: Decimal, _ baseline: Decimal?, unit: Fact.Unit = .count) -> Fact {
    Fact(metric: metric, unit: unit, value: value, baseline: baseline, period: .lastSevenDays)
}

/// The demo account's numbers.
private let demoFacts = [
    fact(.newJoins, 386, 342),                                                        // +13%
    fact(.raised, 23_480, 21_740, unit: .money(currencyCode: "USD")),                 // +8%
    fact(.averageGift, Decimal(string: "57.27")!, Decimal(string: "59.56")!,
         unit: .money(currencyCode: "USD")),                                          // −4%
    fact(.emailOpenRate, Decimal(string: "38.2")!, Decimal(string: "39.6")!, unit: .percent),  // −1.4 pts
]

struct InsightRulesTests {
    @Test func ratesScoreByPoints() {
        let small = fact(.emailOpenRate, Decimal(string: "38.2")!, Decimal(string: "39.6")!, unit: .percent)
        let large = fact(.emailOpenRate, 30, Decimal(string: "32.5")!, unit: .percent)
        #expect(abs(InsightRules.score(small)! - 7) < 0.001)
        #expect(abs(InsightRules.score(large)! - 12.5) < 0.001)
    }

    @Test func highlightsTheBiggestMover() {
        #expect(InsightRules.pulseHighlight(from: demoFacts)?.metric == .newJoins)
    }

    @Test func aBigRateMoveCanWin() {
        let facts = demoFacts + [fact(.emailOpenRate, 25, 30, unit: .percent)]  // 5 pts → 25
        #expect(InsightRules.pulseHighlight(from: facts)?.metric == .emailOpenRate)
    }

    @Test func smallMovesAreNotHighlighted() {
        let quiet = [fact(.newJoins, 100, 98), fact(.raised, 1000, 1030, unit: .money(currencyCode: "USD"))]
        #expect(InsightRules.pulseHighlight(from: quiet) == nil)
    }

    @Test func theThresholdIsTenPercentOrTwoPoints() {
        #expect(InsightRules.pulseHighlight(from: [fact(.newJoins, 107, 100)]) == nil)  // 7%
        #expect(InsightRules.pulseHighlight(from: [fact(.newJoins, 110, 100)])?.metric == .newJoins)  // 10%
        let opensDown = fact(.emailOpenRate, Decimal(string: "38.2")!, Decimal(string: "39.6")!, unit: .percent)
        #expect(InsightRules.pulseHighlight(from: [opensDown]) == nil)  // 1.4 pts
        #expect(InsightRules.pulseHighlight(from: [fact(.emailOpenRate, 38, 40, unit: .percent)])?.metric == .emailOpenRate)  // 2 pts
    }

    @Test func supportersAreNeverTheHighlight() {
        #expect(InsightRules.pulseHighlight(from: [fact(.supporters, 2000, 1000)]) == nil)
    }
}

struct TemplateInsightsTests {
    @Test func writesAboutTheHighlight() throws {
        let insight = try #require(TemplateInsights.pulse(facts: demoFacts))
        #expect(insight.title == "More people joined in the last 7 days")
        #expect(insight.severity == .opportunity)
        #expect(insight.explanation.contains("386"))
        #expect(insight.explanation.contains("342"))
        #expect(insight.explanation.contains("13%"))
        #expect(insight.suggestedAction != nil)
    }

    @Test func aDropNeedsAttention() throws {
        let facts = [fact(.raised, 8_000, 10_000, unit: .money(currencyCode: "USD"))]  // −20%
        let insight = try #require(TemplateInsights.pulse(facts: facts))
        #expect(insight.title == "Giving dipped in the last 7 days")
        #expect(insight.severity == .attention)
        #expect(insight.explanation.contains("down 20%"))
    }

    @Test func quietWeeksGetASteadyNote() throws {
        let quiet = [fact(.newJoins, 100, 98), fact(.raised, 1000, 1030, unit: .money(currencyCode: "USD"))]
        let insight = try #require(TemplateInsights.pulse(facts: quiet))
        #expect(insight.id == "template.steady")
        #expect(insight.severity == .neutral)
        #expect(insight.suggestedAction == nil)
        #expect(insight.explanation == "Your new supporters and giving are close to the 7 days before.")
    }

    @Test func followsTheChosenPeriod() throws {
        let joins = Fact(metric: .newJoins, unit: .count, value: 20, baseline: 10, period: .yesterday)
        let yesterday = try #require(TemplateInsights.pulse(facts: [joins]))
        #expect(yesterday.title == "More people joined yesterday")
        #expect(yesterday.explanation == "20 people joined yesterday, up 100% from 10 the day before.")

        let raised = Fact(metric: .raised, unit: .money(currencyCode: "USD"), value: 8_000, baseline: 10_000, period: .lastMonth)
        let lastMonth = try #require(TemplateInsights.pulse(facts: [raised]))
        #expect(lastMonth.title == "Giving dipped last month")
        #expect(lastMonth.explanation == "You raised $8,000 last month, down 20% from $10,000 in the month before.")

        let quiet = Fact(metric: .newJoins, unit: .count, value: 100, baseline: 98, period: .lastThirtyDays)
        let steady = try #require(TemplateInsights.pulse(facts: [quiet]))
        #expect(steady.title == "A steady 30 days")
        #expect(steady.explanation == "Your new supporters are close to the 30 days before.")
    }

    @Test func nothingToSayWithoutWeeklyFacts() {
        #expect(TemplateInsights.pulse(facts: []) == nil)
        #expect(TemplateInsights.pulse(facts: [fact(.supporters, 10, 5)]) == nil)
    }

    @Test func insightsOnlyCiteFactsThatExist() throws {
        let known = Set(demoFacts.map(\.id))
        let insight = try #require(TemplateInsights.pulse(facts: demoFacts))
        #expect(!insight.factIDs.isEmpty)
        #expect(insight.factIDs.allSatisfy(known.contains))
    }

    @Test func copySaysLastSevenDaysNotThisWeek() throws {
        for metric: Fact.Metric in [.newJoins, .raised, .averageGift, .emailOpenRate] {
            for (value, baseline): (Decimal, Decimal) in [(200, 100), (50, 100)] {
                let unit: Fact.Unit = metric == .emailOpenRate ? .percent : .count
                let insight = try #require(TemplateInsights.pulse(facts: [fact(metric, value, baseline, unit: unit)]))
                let copy = [insight.title, insight.explanation, insight.suggestedAction ?? ""].joined(separator: " ").lowercased()
                #expect(!copy.contains("this week"), "\(metric): \(copy)")
                #expect(!copy.contains("last week"), "\(metric): \(copy)")
            }
        }
    }
}

struct HighlightsTests {
    @Test func biggestMoveFirstAndSupportersLeftOut() {
        let facts = [fact(.supporters, 2000, 1000), fact(.newJoins, 120, 100), fact(.raised, 50, 100)]
        #expect(InsightRules.highlights(from: facts).map(\.metric) == [.raised, .newJoins])
    }

    @Test func keepsToTheLimit() {
        let facts = [fact(.newJoins, 200, 100), fact(.raised, 300, 100), fact(.averageGift, 150, 100)]
        #expect(InsightRules.highlights(from: facts, limit: 2).map(\.metric) == [.raised, .newJoins])
    }
}

struct DigestTests {
    @Test func demoWeekIsOneMoverThenSteady() {
        let digest = TemplateInsights.digest(facts: demoFacts)
        #expect(digest.map(\.severity) == [.opportunity, .neutral])
        #expect(digest[0].factIDs == ["newJoins.lastSevenDays"])
        #expect(digest[1].title == "Everything else held steady")
        #expect(digest[1].factIDs == ["raised.lastSevenDays", "averageGift.lastSevenDays", "emailOpenRate.lastSevenDays"])
        #expect(digest[1].explanation == "Your giving, average gift, and email opens are close to the 7 days before.")
    }

    @Test func needsAttentionComesFirst() {
        let facts = [fact(.newJoins, 200, 100), fact(.raised, 8_000, 10_000, unit: .money(currencyCode: "USD"))]
        #expect(TemplateInsights.digest(facts: facts).map(\.severity) == [.attention, .opportunity])
    }

    @Test func noSteadyNoteWhenEverythingMoved() {
        let facts = [fact(.newJoins, 200, 100), fact(.averageGift, 30, 60, unit: .money(currencyCode: "USD"))]
        #expect(!TemplateInsights.digest(facts: facts).contains { $0.severity == .neutral })
    }

    @Test func quietWeekIsJustTheSteadyNote() {
        let digest = TemplateInsights.digest(facts: [fact(.raised, 1000, 1030, unit: .money(currencyCode: "USD"))])
        #expect(digest.count == 1)
        #expect(digest[0].title == "A steady 7 days")
        #expect(digest[0].explanation == "Your giving is close to the 7 days before.")
    }

    @Test func nothingWithoutFacts() {
        #expect(TemplateInsights.digest(facts: []).isEmpty)
        #expect(TemplateInsights.digest(facts: [fact(.supporters, 10, 5)]).isEmpty)
    }
}

struct InsightFigureTests {
    @Test func oneFactShowsNowAndBefore() {
        let figures = InsightFigure.figures(for: ["newJoins.lastSevenDays"], in: demoFacts)
        #expect(figures == [InsightFigure(value: "386", label: "last 7 days"),
                            InsightFigure(value: "342", label: "the 7 days before")])
    }

    @Test func severalFactsShowOneChipEach() {
        let figures = InsightFigure.figures(for: ["raised.lastSevenDays", "emailOpenRate.lastSevenDays"], in: demoFacts)
        #expect(figures.map(\.label) == ["raised", "email opens"])
        #expect(figures.map(\.value) == ["$23,480", "38.2%"])
    }

    @Test func unknownFactsAreSkipped() {
        #expect(InsightFigure.figures(for: ["made.up"], in: demoFacts).isEmpty)
    }
}

struct InsightCheckTests {
    private let joinsUp = fact(.newJoins, 386, 342)
    private let givingDown = fact(.raised, 8_000, 10_000, unit: .money(currencyCode: "USD"))

    private func draft(_ severity: Insight.Severity = .good, ids: [String] = ["newJoins.lastSevenDays"],
                       title: String = "More people are joining", explanation: String = "New supporters are finding you.",
                       action: String? = "Send them a warm welcome.") -> InsightDraft {
        InsightDraft(title: title, severity: severity, factIDs: ids, explanation: explanation, suggestedAction: action)
    }

    @Test func aGoodDraftBecomesAnInsight() throws {
        let insight = try #require(InsightCheck.validated([draft()], facts: [joinsUp]).first)
        #expect(insight.title == "More people are joining")
        #expect(insight.factIDs == ["newJoins.lastSevenDays"])
    }

    @Test func unknownFactIDsAreDropped() {
        #expect(InsightCheck.validated([draft(ids: ["made.up"])], facts: [joinsUp]).isEmpty)
        let mixed = InsightCheck.validated([draft(ids: ["made.up", "newJoins.lastSevenDays"])], facts: [joinsUp])
        #expect(mixed.first?.factIDs == ["newJoins.lastSevenDays"])
    }

    @Test func draftsMayQuoteTheirFactsFigures() {
        #expect(InsightCheck.validated([draft(title: "New joins rose 13%")], facts: [joinsUp]).count == 1)
        let quoted = "386 people joined in the last 7 days, up from 342 in the 7 days before."
        #expect(InsightCheck.validated([draft(explanation: quoted)], facts: [joinsUp]).count == 1)
    }

    @Test func draftsWithOtherNumbersAreDropped() {
        // 386 − 342 = 44: true, but worked out by the model.
        #expect(InsightCheck.validated([draft(explanation: "You gained 44 more supporters.")], facts: [joinsUp]).isEmpty)
        #expect(InsightCheck.validated([draft(action: "Email them within 2 days.")], facts: [joinsUp]).isEmpty)
        // A figure from another fact, attached to this one.
        #expect(InsightCheck.validated([draft(explanation: "You raised $8,000.")], facts: [joinsUp, givingDown]).isEmpty)
    }

    @Test func draftsMentioningWeeksAreDropped() {
        #expect(InsightCheck.validated([draft(explanation: "More people joined this week.")], facts: [joinsUp]).isEmpty)
        #expect(InsightCheck.validated([draft(explanation: "More than last week.")], facts: [joinsUp]).isEmpty)
        #expect(InsightCheck.validated([draft(title: "Donations fell in the past week")], facts: [joinsUp]).isEmpty)
    }

    @Test func draftsWithAmountsInWordsAreDropped() {
        #expect(InsightCheck.validated([draft(title: "Donations dropped by half")], facts: [joinsUp]).isEmpty)
        #expect(InsightCheck.validated([draft(explanation: "Twice as many people joined.")], facts: [joinsUp]).isEmpty)
        #expect(InsightCheck.validated([draft(explanation: "Sign-ups rose by a few percent.")], facts: [joinsUp]).isEmpty)
        #expect(InsightCheck.validated([draft(explanation: "You've lost four members, down from seven.")], facts: [joinsUp]).isEmpty)
        // "one" reads naturally and carries no figure.
        #expect(InsightCheck.validated([draft(action: "Send one warm welcome email.")], facts: [joinsUp]).count == 1)
    }

    @Test func draftsSpeakingAsWeAreDropped() {
        #expect(InsightCheck.validated([draft(explanation: "We’re thrilled to see this.")], facts: [joinsUp]).isEmpty)
        #expect(InsightCheck.validated([draft(action: "Let's keep going!")], facts: [joinsUp]).isEmpty)
        #expect(InsightCheck.validated([draft(explanation: "Your list grew. Trust us.")], facts: [joinsUp]).isEmpty)
        // "us" inside another word is fine.
        #expect(InsightCheck.validated([draft(explanation: "Your supporters are enthusiastic.")], facts: [joinsUp]).count == 1)
    }

    @Test func severityMustMatchTheFigures() {
        let ids = ["raised.lastSevenDays"]
        #expect(InsightCheck.validated([draft(.good, ids: ids)], facts: [givingDown]).isEmpty)
        #expect(InsightCheck.validated([draft(.opportunity, ids: ids)], facts: [givingDown]).isEmpty)
        #expect(InsightCheck.validated([draft(.attention, ids: ids)], facts: [givingDown]).count == 1)
        #expect(InsightCheck.validated([draft(.attention)], facts: [joinsUp]).isEmpty)
    }

    @Test func secondDraftAboutTheSameFactIsDropped() {
        #expect(InsightCheck.validated([draft(), draft(title: "Another take")], facts: [joinsUp]).count == 1)
    }

    @Test func templatesFillWhatTheModelMissed() {
        let written = InsightCheck.validated([draft()], facts: [joinsUp, givingDown])
        let filled = InsightCheck.filling(written, highlights: [joinsUp, givingDown])
        #expect(filled.map(\.factIDs) == [["raised.lastSevenDays"], ["newJoins.lastSevenDays"]])
        #expect(filled[0].id.hasPrefix("template."))
        #expect(filled[1].id.hasPrefix("ai."))
    }

    @Test func answersWithNumbersShowFiguresInstead() {
        let answer = InsightCheck.answer(text: "You raised $23,480.", factIDs: ["raised.lastSevenDays"], facts: demoFacts)
        #expect(!answer.text.contains { $0.isNumber })
        #expect(answer.factIDs == ["raised.lastSevenDays"])

        let nothing = InsightCheck.answer(text: "About 12.", factIDs: [], facts: demoFacts)
        #expect(nothing.text == InsightCheck.cantAnswer)
    }

    @Test func plainAnswersPassThrough() {
        let answer = InsightCheck.answer(text: "Giving rose a little.", factIDs: ["raised.lastSevenDays", "x"], facts: demoFacts)
        #expect(answer == NumbersAnswer(text: "Giving rose a little.", factIDs: ["raised.lastSevenDays"]))
    }
}

struct PromptLineTests {
    @Test func describesTheFactForTheModel() {
        #expect(InsightWriter.promptLine(demoFacts[0])
                == "id: newJoins.lastSevenDays. New joins: 386 in the last 7 days, 342 in the 7 days before (up 13%). This is good news.")
        #expect(InsightWriter.promptLine(demoFacts[3]).hasSuffix("(down 1.4 pts). This needs attention."))
    }
}
