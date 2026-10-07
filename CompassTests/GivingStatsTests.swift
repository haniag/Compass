//
//  GivingStatsTests.swift
//  CompassTests
//
//  One page's gifts in the reporting currency, and the change against the days before.
//

import Foundation
import Testing
@testable import Compass

private func giving(usd single: Decimal, _ recurring: Decimal, singleGifts: Int, recurringGifts: Int,
                    other: [String: Decimal] = [:]) -> ENPageGiving {
    var raised = other
    raised["USD"] = single + recurring
    return ENPageGiving(campaignId: 1, name: "Page", gifts: singleGifts + recurringGifts,
                        singleGifts: singleGifts, recurringGifts: recurringGifts,
                        raised: raised, raisedSingle: ["USD": single], raisedRecurring: ["USD": recurring])
}

struct GivingStatsTests {
    @Test func summaryInTheReportingCurrency() throws {
        let summary = GivingStats.Summary(giving(usd: 142_900, 41_350, singleGifts: 1_960, recurringGifts: 318), currency: "USD")
        #expect(summary.raised == 184_250)
        #expect(summary.gifts == 2_278)
        #expect(summary.single == 142_900)
        #expect(summary.recurring == 41_350)
        let average = try #require(summary.averageGift)
        #expect(abs(NSDecimalNumber(decimal: average).doubleValue - 80.88) < 0.01)
        let share = try #require(summary.singleShare)
        #expect(abs(share - 0.7756) < 0.001)
        #expect(!summary.hasOtherCurrencies)
    }

    @Test func noGiftsMeansZerosNotAnError() {
        let summary = GivingStats.Summary(nil, currency: "USD")
        #expect(summary.raised == 0)
        #expect(summary.gifts == 0)
        #expect(summary.averageGift == nil)
        #expect(summary.singleShare == nil)
    }

    @Test func freeTicketsHaveNoAverage() {
        // Real test-account event page: 7 "gifts", all $0.
        let tickets = GivingStats.Summary(giving(usd: 0, 0, singleGifts: 7, recurringGifts: 0), currency: "USD")
        #expect(tickets.gifts == 7)
        #expect(tickets.averageGift == nil)
        let zero = Fact.format(tickets.raised, unit: .money(currencyCode: "USD"))
        #expect(!zero.contains(Locale.current.decimalSeparator ?? "."))  // "$0", not "$0.00"
    }

    @Test func noAverageWhenSomeGiftsCameInOtherCurrencies() {
        let mixed = GivingStats.Summary(giving(usd: 1_000, 0, singleGifts: 12, recurringGifts: 0, other: ["EUR": 500, "GBP": 0]),
                                        currency: "USD")
        #expect(mixed.hasOtherCurrencies)
        #expect(mixed.raised == 1_000)  // the euros aren't added in
        #expect(mixed.averageGift == nil)
        // A zero in another currency doesn't count.
        let zeros = GivingStats.Summary(giving(usd: 1_000, 0, singleGifts: 10, recurringGifts: 0, other: ["GBP": 0]), currency: "USD")
        #expect(!zeros.hasOtherCurrencies)
        #expect(zeros.averageGift == 100)
    }

    @Test func changeAgainstTheDaysBefore() throws {
        let now = GivingStats.Summary(giving(usd: 23_480, 0, singleGifts: 410, recurringGifts: 0), currency: "USD")
        let before = GivingStats.Summary(giving(usd: 21_740, 0, singleGifts: 365, recurringGifts: 0), currency: "USD")
        let change = try #require(GivingStats.change(now, from: before))
        #expect(change.badgeText == "▲ 8%")
        #expect(change.isGood == true)
        #expect(GivingStats.change(now, from: GivingStats.Summary(nil, currency: "USD")) == nil)
    }

    @Test func bestDayIsTheEarliestHighest() throws {
        let days = [1_200, 3_900, 2_240, 3_900].enumerated().map { offset, amount in
            GivingStats.DailyTotal(day: TestDates.date(2026, 9, 24 + offset), raised: Decimal(amount))
        }
        let best = try #require(GivingStats.bestDay(days))
        #expect(TestDates.parts(best.day) == (2026, 9, 25))
        #expect(best.raised == 3_900)
    }

    @Test func noBestDayWithoutGifts() {
        let quiet = [GivingStats.DailyTotal(day: TestDates.date(2026, 9, 24), raised: 0)]
        #expect(GivingStats.bestDay(quiet) == nil)
        #expect(GivingStats.bestDay([]) == nil)
    }
}
