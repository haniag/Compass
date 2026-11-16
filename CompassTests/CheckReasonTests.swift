//
//  CheckReasonTests.swift
//  CompassTests
//
//  When a check rejects generated text it says why, so the model can be told what
//  to fix on its next try. The reasons never change what passes.
//

import Foundation
import Testing
@testable import Compass

private func fact(_ metric: Fact.Metric, _ value: Decimal, _ baseline: Decimal?,
                  unit: Fact.Unit = .count, period: Fact.Period = .lastSevenDays) -> Fact {
    Fact(metric: metric, unit: unit, value: value, baseline: baseline, period: period)
}

private let joinsUp = fact(.newJoins, 386, 342)                        // up 13%
private let opensDown = fact(.emailOpenRate, Decimal(string: "38.2")!,
                             Decimal(string: "39.6")!, unit: .percent) // down 1.4 pts

struct CheckReasonTests {
    private func problem(_ text: String, _ facts: [Fact] = [joinsUp]) -> FigureCheck.Problem? {
        FigureCheck.problem(quoting: facts, in: text)
    }

    @Test func namesTheWordOrFigureThatBrokeTheRules() {
        #expect(problem("We welcomed 386 new people.") == .speaksAsOrganization(word: "we"))
        #expect(problem("386 joined last week.") == .wrongTimeWords(word: "week"))
        #expect(problem("386 joined this month.") == .wrongTimeWords(word: "this month"))
        #expect(problem("386 joined in the month.") == .wrongTimeWords(word: "month"))
        #expect(problem("Hundreds of people joined.") == .amountInWords(word: "hundreds"))
        #expect(problem("Joins rose by half.") == .amountInWords(word: "half"))
        #expect(problem("Joins rose a few percent.") == .percentWithoutNumber)
        #expect(problem("You gained 44 more supporters.") == .unknownFigure(44))
        #expect(problem("Joins rose 13% to 386 in the last 7 days.") == nil)
    }

    @Test func lastMonthStillRejectsThisMonth() {
        let monthly = [fact(.newJoins, 386, 342, period: .lastMonth)]
        #expect(problem("386 people joined last month.", monthly) == nil)
        #expect(problem("386 people joined this month.", monthly) == .wrongTimeWords(word: "this month"))
    }

    @Test func reasonsAgreeWithTheTrueFalseChecks() {
        let texts = ["We did it.", "386 joined today.", "A dozen joined.", "Up 13% to 386 in the last 7 days.",
                     "Up 14%.", "fifty percent more", "Twice as many joined.", "Your supporters showed up."]
        for text in texts {
            #expect(FigureCheck.quotesOnlyFigures(of: [joinsUp], in: text) == (problem(text) == nil), "\(text)")
        }
    }

    @Test func namesAFigureSaidToMoveTheWrongWay() {
        let changes = [joinsUp, opensDown].compactMap(\.change)
        #expect(FigureCheck.directionProblem("Joins fell 13%.", changes: changes) == .wrongDirection(figure: 13, actuallyUp: true))
        #expect(FigureCheck.directionProblem("Opens climbed 1.4 pts.", changes: changes)
                == .wrongDirection(figure: Decimal(string: "1.4")!, actuallyUp: false))
        #expect(FigureCheck.directionProblem("Joins rose 13%.", changes: changes) == nil)
    }

    @Test func briefingReasons() {
        let facts = [joinsUp, opensDown]
        #expect(BriefingCheck.problem(with: "", facts: facts) == .empty)
        let long = Array(repeating: "Your supporters keep showing up.", count: 15).joined(separator: " ")
        #expect(BriefingCheck.problem(with: long, facts: facts) == .tooLong(maxWords: BriefingCheck.maxWords))
        #expect(BriefingCheck.problem(with: "New joins fell 13% to 386 in the last 7 days.", facts: facts)
                == .wrongDirection(figure: 13, actuallyUp: true))
        #expect(BriefingCheck.problem(with: "New joins rose 13% to 386 in the last 7 days.", facts: facts) == nil)
    }

    @Test func digestReasonsNameThePart() throws {
        func draft(title: String = "More people are joining", explanation: String = "New supporters are finding you.",
                   action: String? = "Send them a warm welcome.") -> InsightDraft {
            InsightDraft(title: title, severity: .good, factIDs: [joinsUp.id], explanation: explanation, suggestedAction: action)
        }
        #expect(InsightCheck.wordingProblem(in: draft(), citedFacts: [joinsUp]) == nil)
        #expect(InsightCheck.wordingProblem(in: draft(action: nil), citedFacts: [joinsUp]) == nil)
        let empty = try #require(InsightCheck.wordingProblem(in: draft(title: "  "), citedFacts: [joinsUp]))
        #expect(empty.part == "title" && empty.problem == .empty)
        let week = try #require(InsightCheck.wordingProblem(in: draft(explanation: "More joined this week."), citedFacts: [joinsUp]))
        #expect(week.part == "explanation" && week.problem == .wrongTimeWords(word: "week"))
        let figure = try #require(InsightCheck.wordingProblem(in: draft(action: "Email them within 2 days."), citedFacts: [joinsUp]))
        #expect(figure.part == "suggestedAction" && figure.problem == .unknownFigure(2))
    }

    @Test func correctionsSayWhatToFix() {
        let week = BriefingWriter.correction(.wrongTimeWords(word: "week"), period: .lastSevenDays)
        #expect(week.contains("\"week\"") && week.contains("in the last 7 days"))
        let figure = InsightWriter.correction(("explanation", .unknownFigure(44)), period: .lastSevenDays)
        #expect(figure.contains("explanation") && figure.contains("44"))
        // A correction never hands the model a new figure to copy: only the one it wrote.
        let numbers = FigureCheck.numbers(in: figure)
        #expect(numbers == [44])
    }
}
