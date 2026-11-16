//
//  EmailSummaryTests.swift
//  CompassTests
//
//  The Email tab's summary: what Swift picks out of the sends, the plain-words version,
//  and the check on what Apple Intelligence writes.
//

import Foundation
import Testing
@testable import Compass

private let now = TestDates.date(2026, 11, 10)
private let period = DayRange.last(30, daysBefore: now, calendar: TestDates.utc)

private func send(_ name: String, daysAgo: Int, sent: Int = 1_000, opens: Int = 400, clicks: Int = 30,
                  unsubscribes: Int = 1) -> ENBroadcast {
    let day = TestDates.utc.date(byAdding: .day, value: -daysAgo, to: now)!
    return ENBroadcast(id: daysAgo, name: name, sentOn: day, sent: sent, opens: opens, clicks: clicks,
                       unsubscribes: unsubscribes)
}

/// Three emails in the last 30 days and two in the 30 before. "Fall Appeal · Email 3" has the best click rate.
private let sends = [
    send("Monthly newsletter", daysAgo: 3, clicks: 40),
    send("Fall Appeal · Email 3", daysAgo: 9, clicks: 91),
    send("Volunteer thank-you", daysAgo: 20, clicks: 20),
    send("Summer report", daysAgo: 40, opens: 420, clicks: 60),
    send("Summer appeal", daysAgo: 50, opens: 420, clicks: 60),
]

private func findings(_ sends: [ENBroadcast]) -> EmailFindings? {
    EmailFindings.make(from: sends, in: period, calendar: TestDates.utc)
}

struct EmailFindingsTests {
    @Test func nothingToSayWhenNothingWasSent() {
        #expect(findings([send("Old", daysAgo: 45)]) == nil)
    }

    @Test func picksTheBestClickedEmail() throws {
        let found = try #require(findings(sends))
        #expect(found.sendsInPeriod == 3)
        #expect(found.bestSend == .init(name: "Fall Appeal · Email 3", rate: Decimal(string: "9.1")!))
        #expect(found.highUnsubscribeSend == nil)
        #expect(found.fatigue == nil)
    }

    @Test func noBestEmailFromFewerThanThree() throws {
        let found = try #require(findings(Array(sends.dropFirst())))
        #expect(found.bestSend == nil)
    }

    @Test func smallSendsAndUnquotableNamesAreNeverNamed() throws {
        let found = try #require(findings([
            send("Seed list test", daysAgo: 2, sent: 20, clicks: 20),
            send("The “big” one", daysAgo: 4, clicks: 90),
            send("A", daysAgo: 6, clicks: 10),
            send("B", daysAgo: 8, clicks: 10),
        ]))
        #expect(found.bestSend == nil)
    }

    @Test func listFatigueComesFirst() throws {
        // Five usual emails (0.1% unsubscribed), then three that lost 0.5%.
        let tired = (0..<3).map { send("Appeal \($0)", daysAgo: 2 + $0, clicks: 50 + $0, unsubscribes: 5) }
            + (0..<5).map { send("Earlier \($0)", daysAgo: 12 + $0) }
        let found = try #require(findings(tired))
        #expect(found.fatigue == EmailStats.Fatigue(sends: 3, timesUsual: 5))
        #expect(found.highUnsubscribeSend?.name == "Appeal 0")
        let support = try #require(found.support)
        #expect(support.name == nil)
        #expect(support.line.contains("5 times the usual rate"))
    }
}

struct EmailSummaryCheckTests {
    private let found = findings(sends)!
    private var opens: String { found.rates[0].formattedValue }
    private var clicks: String { found.rates[1].formattedValue }

    @Test func theTemplatePassesItsOwnCheck() {
        #expect(found.template.contains("“Fall Appeal · Email 3”"))
        #expect(found.template.contains(opens))
        #expect(EmailSummaryCheck.isSafe(found.template, findings: found))
    }

    @Test func allowsTheAppsFiguresAndTheEmailsName() {
        let text = "Opens held at \(opens) in the last 30 days and clicks reached \(clicks) across 3 emails. "
            + "Take a look at what made \"Fall Appeal · Email 3,\" your most-clicked email, work so well."
        #expect(EmailSummaryCheck.isSafe(text, findings: found))
    }

    @Test func rejectsAnEmailTheAppDidNotName() {
        #expect(!EmailSummaryCheck.isSafe("Opens were \(opens). Reuse what worked in “Spring update”.", findings: found))
        #expect(!EmailSummaryCheck.isSafe("Opens were \(opens). Reuse what worked in “Fall Appeal”.", findings: found))
        // The other emails' names weren't handed over either.
        #expect(!EmailSummaryCheck.isSafe("Opens were \(opens). “Monthly newsletter” did well.", findings: found))
    }

    @Test func rejectsFiguresTheModelWorkedOut() {
        #expect(!EmailSummaryCheck.isSafe("Opens were \(opens), and 1,200 supporters opened an email.", findings: found))
        // The 3 in the email's name isn't a figure the text may use elsewhere... but 3 emails were sent.
        #expect(EmailSummaryCheck.isSafe("You sent 3 emails in the last 30 days.", findings: found))
        #expect(!EmailSummaryCheck.isSafe("You sent 4 emails in the last 30 days.", findings: found))
    }

    @Test func rejectsARateSaidToMoveTheWrongWay() throws {
        // Opens went from 42% to 40%: down.
        let change = try #require(found.rates[0].change)
        #expect(change.direction == .down)
        #expect(EmailSummaryCheck.isSafe("Opens fell \(change.text) to \(opens) in the last 30 days.", findings: found))
        #expect(!EmailSummaryCheck.isSafe("Opens rose \(change.text) to \(opens) in the last 30 days.", findings: found))
        #expect(!EmailSummaryCheck.isSafe("Clicks held steady, though opens were up \(change.text).", findings: found))
    }

    @Test func rejectsWrongPeriodsAndSpeakingAsTheOrganization() {
        #expect(!EmailSummaryCheck.isSafe("Opens were \(opens) this week.", findings: found))
        #expect(!EmailSummaryCheck.isSafe("Opens were \(opens) this month.", findings: found))
        #expect(!EmailSummaryCheck.isSafe("Our opens were \(opens) in the last 30 days.", findings: found))
    }

    @Test func rejectsUnfinishedQuotesAndLongAnswers() {
        #expect(!EmailSummaryCheck.isSafe("Opens were \(opens). Look at \"Fall Appeal · Email 3 again.", findings: found))
        let long = Array(repeating: "Your supporters keep reading.", count: 20).joined(separator: " ")
        #expect(!EmailSummaryCheck.isSafe(long, findings: found))
    }

    @Test func thePromptCarriesOnlyTheChosenLines() {
        let prompt = EmailSummaryWriter.prompt(for: found)
        #expect(prompt.contains("Best email: “Fall Appeal · Email 3”"))
        #expect(prompt.contains("Emails sent in the last 30 days: 3."))
        #expect(!prompt.contains("Monthly newsletter"))
        #expect(prompt.contains("Next step:"))
    }
}
