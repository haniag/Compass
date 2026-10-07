//
//  EmailStatsTests.swift
//  CompassTests
//
//  Email rates, the 30-day comparison, best day to send, and unsubscribe alerts.
//

import Foundation
import Testing
@testable import Compass

private func send(on day: Date, sent: Int = 1_000, opens: Int = 0, clicks: Int = 0, unsubscribes: Int = 0) -> ENBroadcast {
    ENBroadcast(id: Int(day.timeIntervalSince1970) + sent + unsubscribes, name: "Email", sentOn: day,
                sent: sent, opens: opens, clicks: clicks, unsubscribes: unsubscribes)
}

/// "0.05 pts", written the way the app writes it in the test machine's locale.
private func pts(_ number: Double, decimals: Int) -> String {
    "\(number.formatted(.number.precision(.fractionLength(decimals)))) pts"
}

struct EmailTotalsTests {
    @Test func bigSendsCountForMore() throws {
        let totals = EmailStats.Totals([
            send(on: TestDates.date(2026, 10, 1), sent: 900, opens: 360, clicks: 45, unsubscribes: 2),
            send(on: TestDates.date(2026, 10, 2), sent: 100, opens: 0),
        ])
        #expect(totals.sends == 2)
        #expect(totals.openRate == 36)  // 360 of 1,000, not the average of 40% and 0%
        #expect(totals.clickRate == Decimal(string: "4.5"))
        #expect(totals.unsubscribeRate == Decimal(string: "0.2"))
    }

    @Test func ratesNeverGoOver100Percent() {
        // Real test-account rows: 3 opens from 2 emails, and a click on a send of 0.
        let totals = EmailStats.Totals([
            send(on: TestDates.date(2026, 9, 11), sent: 2, opens: 3, clicks: 3),
            send(on: TestDates.date(2026, 9, 2), sent: 0, clicks: 1),
        ])
        #expect(totals.openRate == 100)
        #expect(totals.clickRate == 100)
    }

    @Test func noRatesWhenNothingWasSent() {
        let totals = EmailStats.Totals([ENBroadcast]())
        #expect(totals.openRate == nil)
        #expect(totals.unsubscribeRate == nil)
    }
}

struct EmailRateTests {
    private let now = TestDates.date(2026, 10, 7, 11, 0)
    private var period: DayRange { DayRange.last(30, daysBefore: now, calendar: TestDates.utc) }

    private var sends: [ENBroadcast] {
        [
            send(on: TestDates.date(2026, 10, 7), sent: 5_000, opens: 5_000),  // today: not over yet
            send(on: TestDates.date(2026, 10, 5), opens: 380, clicks: 41, unsubscribes: 3),
            send(on: TestDates.date(2026, 9, 20), opens: 384, clicks: 41, unsubscribes: 2),
            send(on: TestDates.date(2026, 8, 20), opens: 396, clicks: 38, unsubscribes: 2),  // the 30 days before
            send(on: TestDates.date(2026, 7, 1), sent: 5_000),  // too old
        ]
    }

    @Test func lastThirtyDaysAgainstTheThirtyBefore() throws {
        let rates = EmailStats.rates(sends, in: period, calendar: TestDates.utc)
        #expect(rates.map(\.kind) == [.opens, .clicks, .unsubscribes])

        let opens = rates[0]
        #expect(opens.value == Decimal(string: "38.2"))
        #expect(opens.baseline == Decimal(string: "39.6"))
        let opensChange = try #require(opens.change)
        #expect(opensChange.direction == .down)
        #expect(opensChange.isGood == false)
        #expect(opensChange.text == pts(1.4, decimals: 1))

        let clicks = try #require(rates[1].change)
        #expect(clicks.direction == .up)
        #expect(clicks.isGood == true)
        #expect(clicks.text == pts(0.3, decimals: 1))
    }

    @Test func moreUnsubscribesIsBadAndGetsTwoDecimals() throws {
        let unsubscribes = EmailStats.rates(sends, in: period, calendar: TestDates.utc)[2]
        #expect(unsubscribes.value == Decimal(string: "0.25"))
        #expect(unsubscribes.formattedValue.contains("0") && unsubscribes.formattedValue.contains("25"))
        let change = try #require(unsubscribes.change)
        #expect(change.direction == .up)
        #expect(change.isGood == false)
        #expect(change.text == pts(0.05, decimals: 2))
    }

    @Test func nothingSentMeansNoRates() {
        let old = [send(on: TestDates.date(2026, 1, 1), opens: 400)]
        #expect(EmailStats.rates(old, in: period, calendar: TestDates.utc).isEmpty)
    }

    @Test func nothingSentBeforeMeansNoChange() {
        let recent = [send(on: TestDates.date(2026, 10, 1), opens: 400)]
        let rates = EmailStats.rates(recent, in: period, calendar: TestDates.utc)
        #expect(rates.first?.change == nil)
    }

    @Test(arguments: [("36", "36%"), ("3.2", "3.2%"), ("0.71", "0.71%"), ("0", "0%")])
    func compactPercentForOneSend(value: String, expected: String) throws {
        // Only meaningful in a locale that writes "36%"; skip elsewhere.
        guard Locale.current.decimalSeparator == "." else { return }
        let number = try #require(Decimal(string: value))
        let formatted = EmailFormat.compactPercent(number)
        #expect(formatted.replacingOccurrences(of: "\u{00A0}", with: "") == expected)
    }
}

struct BestDayTests {
    /// Monday first, in UTC.
    private var calendar: Calendar {
        var calendar = TestDates.utc
        calendar.firstWeekday = 2
        return calendar
    }

    // Oct 5 2026 is a Monday.
    private let monday1 = TestDates.date(2026, 9, 28), monday2 = TestDates.date(2026, 10, 5)
    private let tuesday1 = TestDates.date(2026, 9, 29), tuesday2 = TestDates.date(2026, 10, 6)
    private let friday = TestDates.date(2026, 10, 2)

    @Test func allSevenDaysInTheCalendarsOrder() {
        let days = EmailStats.openRateByWeekday([send(on: tuesday2, opens: 450)], calendar: calendar)
        #expect(days.map(\.weekday) == [2, 3, 4, 5, 6, 7, 1])
        #expect(days[1].sends == 1)
        #expect(days[1].openRate == 45)
        #expect(days[2].openRate == nil)  // no Wednesday sends
    }

    @Test func bestDayNeedsTwoSendsOnThatDay() {
        let days = EmailStats.openRateByWeekday([
            send(on: monday1, opens: 320), send(on: monday2, opens: 300),
            send(on: tuesday1, opens: 430), send(on: tuesday2, opens: 450),
            send(on: friday, opens: 600),  // highest, but only one send
        ], calendar: calendar)
        #expect(days[1].openRate == 44)
        #expect(EmailStats.bestWeekday(days) == 3)  // Tuesday
    }

    @Test func noBestDayUntilThreeDaysOfTheWeekHaveSends() {
        let days = EmailStats.openRateByWeekday([
            send(on: monday1, opens: 320), send(on: monday2, opens: 300),
            send(on: tuesday1, opens: 430), send(on: tuesday2, opens: 450),
        ], calendar: calendar)
        #expect(EmailStats.bestWeekday(days) == nil)
    }
}

struct UnsubscribeTests {
    private func sends(unsubscribes: [Int], sent: Int = 1_000) -> [ENBroadcast] {
        unsubscribes.enumerated().map { index, count in
            send(on: TestDates.date(2026, 9, 1 + index), sent: sent, unsubscribes: count)
        }
    }

    @Test func usualRateIsTheMedianOfBigSends() {
        // 0.1%, 0.2%, 0.3%, 0.4%, 5%: one bad send doesn't move the middle.
        let big = sends(unsubscribes: [1, 2, 3, 4, 50])
        let tiny = send(on: TestDates.date(2026, 9, 30), sent: 10, unsubscribes: 5)
        #expect(EmailStats.usualUnsubscribeRate(big + [tiny]) == Decimal(string: "0.3"))
        // An even count averages the middle two.
        #expect(EmailStats.usualUnsubscribeRate(sends(unsubscribes: [1, 2, 3, 4, 5, 6])) == Decimal(string: "0.35"))
    }

    @Test func noUsualRateFromTooFewSends() {
        #expect(EmailStats.usualUnsubscribeRate(sends(unsubscribes: [1, 2, 3, 4])) == nil)
        #expect(EmailStats.usualUnsubscribeRate(sends(unsubscribes: [1, 2, 3, 4, 5], sent: 100)) == nil)
    }

    @Test func highMeansTwiceTheUsualRate() {
        let usual = Decimal(string: "0.2")
        let day = TestDates.date(2026, 10, 1)
        #expect(EmailStats.hasHighUnsubscribes(send(on: day, unsubscribes: 5), usual: usual))   // 0.5%
        #expect(!EmailStats.hasHighUnsubscribes(send(on: day, unsubscribes: 3), usual: usual))  // 0.3%
        #expect(!EmailStats.hasHighUnsubscribes(send(on: day, sent: 100, unsubscribes: 50), usual: usual))  // too small
        #expect(!EmailStats.hasHighUnsubscribes(send(on: day, unsubscribes: 5), usual: nil))
    }

    @Test func aTinyUsualRateDoesntFlagEverything() {
        // Twice 0.01% is 0.02%, but a send must also reach 0.2% to count as high.
        let day = TestDates.date(2026, 10, 1)
        #expect(!EmailStats.hasHighUnsubscribes(send(on: day, sent: 2_000, unsubscribes: 3), usual: Decimal(string: "0.01")))
    }

    @Test func fatigueWhenTheNewestThreeAreAllHigh() {
        // Oldest first on purpose: the newest are found by date.
        let usual = sends(unsubscribes: [2, 2, 2, 2, 2, 2])  // 0.2% each, Sep 1–6
        let recent = (0..<3).map { send(on: TestDates.date(2026, 10, 1 + $0), unsubscribes: 6) }  // 0.6%
        #expect(EmailStats.listFatigue(usual + recent) == EmailStats.Fatigue(sends: 3, timesUsual: 3))
    }

    @Test func noFatigueIfOneOfTheThreeWasNormal() {
        let usual = sends(unsubscribes: [2, 2, 2, 2, 2, 2])
        let recent = [
            send(on: TestDates.date(2026, 10, 1), unsubscribes: 6),
            send(on: TestDates.date(2026, 10, 2), unsubscribes: 2),
            send(on: TestDates.date(2026, 10, 3), unsubscribes: 6),
        ]
        #expect(EmailStats.listFatigue(usual + recent) == nil)
    }
}
