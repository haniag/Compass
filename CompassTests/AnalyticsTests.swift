//
//  AnalyticsTests.swift
//  CompassTests
//
//  Facts, changes, the supporter trend and the Pulse fact builders.
//

import Foundation
import Testing
@testable import Compass

private func fact(_ metric: Fact.Metric, _ value: Decimal, _ baseline: Decimal?,
                  unit: Fact.Unit = .count, higherIsBetter: Bool = true) -> Fact {
    Fact(metric: metric, unit: unit, value: value, baseline: baseline, period: .lastSevenDays, higherIsBetter: higherIsBetter)
}

struct FactTests {
    @Test func percentChange() throws {
        let joins = fact(.newJoins, 386, 342)
        #expect(joins.difference == 44)
        let percent = try #require(joins.percentChange)
        #expect(abs(percent - 12.865) < 0.01)
    }

    @Test func noPercentChangeWithoutAUsableBaseline() {
        #expect(fact(.newJoins, 10, 0).percentChange == nil)
        #expect(fact(.newJoins, 10, nil).percentChange == nil)
        #expect(fact(.newJoins, 10, nil).difference == nil)
        #expect(fact(.newJoins, 10, nil).change == nil)
    }

    @Test func upIsGoodByDefault() throws {
        let change = try #require(fact(.newJoins, 386, 342).change)
        #expect(change.direction == .up)
        #expect(change.text == "13%")
        #expect(change.badgeText == "▲ 13%")
        #expect(change.isGood == true)
        #expect(change.spokenSummary == "up 13 percent")
    }

    @Test func downIsNeedsAttention() throws {
        let change = try #require(fact(.averageGift, Decimal(string: "57.27")!, Decimal(string: "59.56")!,
                                       unit: .money(currencyCode: "USD")).change)
        #expect(change.direction == .down)
        #expect(change.text == "4%")
        #expect(change.isGood == false)
    }

    @Test func lowerIsBetterFlipsGood() throws {
        let change = try #require(fact(.newJoins, 5, 10, higherIsBetter: false).change)
        #expect(change.direction == .down)
        #expect(change.isGood == true)
    }

    @Test func tinyChangesAreFlat() throws {
        let change = try #require(fact(.newJoins, 1001, 1000).change)  // +0.1% rounds to 0%
        #expect(change.direction == .flat)
        #expect(change.isGood == nil)
        #expect(change.badgeText == "No change")
    }

    @Test func ratesChangeInPoints() throws {
        let change = try #require(fact(.emailOpenRate, Decimal(string: "38.2")!, Decimal(string: "39.6")!, unit: .percent).change)
        #expect(change.direction == .down)
        #expect(change.text.hasSuffix(" pts"))
        #expect(change.text.contains("1"))
        #expect(change.text.contains("4"))
        #expect(change.spokenText.hasSuffix(" points"))
    }

    @Test func supportersChangeInPeople() throws {
        let change = try #require(fact(.supporters, 48_312, 48_098).change)
        #expect(change.direction == .up)
        #expect(change.text == 214.formatted())
    }

    @Test func formattedValues() {
        #expect(fact(.newJoins, 48_312, nil).formattedValue == 48_312.formatted())
        let raised = fact(.raised, 23_480, nil, unit: .money(currencyCode: "USD")).formattedValue
        #expect(raised.contains("23"))
        #expect(!raised.contains(".00"))  // whole amounts
        let smallAverage = fact(.averageGift, Decimal(string: "7.5")!, nil, unit: .money(currencyCode: "USD")).formattedValue
        #expect(smallAverage.contains("50"))  // cents kept for small amounts
        #expect(fact(.emailOpenRate, Decimal(string: "38.2")!, nil, unit: .percent).formattedValue.contains("%"))
    }
}

struct SupporterTrendTests {
    private let now = TestDates.date(2026, 9, 24, 12)

    private func point(daysAgo: Double, _ count: Int) -> SupporterTrend.Point {
        SupporterTrend.Point(date: now.addingTimeInterval(-daysAgo * 86_400), count: count)
    }

    @Test func countAtOrBeforeTakesTheNewestEarlierValue() {
        let points = [point(daysAgo: 20, 100), point(daysAgo: 8, 110), point(daysAgo: 1, 120)]
        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        #expect(SupporterTrend.count(atOrBefore: weekAgo, in: points) == 110)
        #expect(SupporterTrend.count(atOrBefore: now, in: points) == 120)
        #expect(SupporterTrend.count(atOrBefore: now.addingTimeInterval(-30 * 86_400), in: points) == nil)
    }

    @Test func weeklyHasOnePointPerWeekEndingNow() {
        let points = (0...14).reversed().map { point(daysAgo: Double($0 * 7) + 0.1, 1000 - $0) }
        let weekly = SupporterTrend.weekly(points, weeks: 12, now: now)
        #expect(weekly.count == 13)  // 12 weeks ago … now
        #expect(weekly.last?.count == 1000)
        #expect(weekly.first?.count == 988)
    }

    @Test func weeklySkipsWeeksBeforeTrackingStarted() {
        let points = [point(daysAgo: 0.5, 500)]
        let weekly = SupporterTrend.weekly(points, weeks: 12, now: now)
        #expect(weekly.count == 1)
        #expect(weekly.first?.count == 500)
    }
}

struct PulseFactsTests {
    private let usdNow = ENDonationAmount(currency: "USD", total: 23_480, average: Decimal(string: "57.27")!)
    private let usdBefore = ENDonationAmount(currency: "USD", total: 21_740, average: Decimal(string: "59.56")!)
    private let eur = ENDonationAmount(currency: "EUR", total: 99_000, average: 300)

    @Test func givingUsesTheReportingCurrencyOnly() throws {
        let facts = PulseFacts.giving(current: [eur, usdNow], previous: [usdBefore], currency: "USD", period: .lastSevenDays)
        let raised = try #require(facts.first { $0.metric == .raised })
        #expect(raised.value == 23_480)
        #expect(raised.baseline == 21_740)
        #expect(raised.unit == .money(currencyCode: "USD"))

        let average = try #require(facts.first { $0.metric == .averageGift })
        #expect(average.value == Decimal(string: "57.27"))
        #expect(average.baseline == Decimal(string: "59.56"))
    }

    @Test func noGiftsInTheCurrencyMeansZeroRaisedAndNoAverage() {
        let facts = PulseFacts.giving(current: [eur], previous: [usdBefore], currency: "USD", period: .lastSevenDays)
        #expect(facts.count == 1)
        #expect(facts[0].metric == .raised)
        #expect(facts[0].value == 0)
        #expect(facts[0].baseline == 21_740)
    }

    @Test func averageGiftHasNoBaselineWhenNothingCameInBefore() throws {
        let facts = PulseFacts.giving(current: [usdNow], previous: [], currency: "USD", period: .lastSevenDays)
        let average = try #require(facts.first { $0.metric == .averageGift })
        #expect(average.baseline == nil)
    }

    @Test func openRateNeedsEmailsSent() {
        let none = ENBroadcastStats(emailsSent: 0, openRate: nil)
        let some = ENBroadcastStats(emailsSent: 100, openRate: Decimal(string: "38.2"))
        #expect(PulseFacts.emailOpenRate(current: none, previous: some, period: .lastSevenDays) == nil)

        let fact = PulseFacts.emailOpenRate(current: some, previous: none, period: .lastSevenDays)
        #expect(fact?.value == Decimal(string: "38.2"))
        #expect(fact?.baseline == nil)
        #expect(fact?.unit == .percent)
    }

    @Test func supportersWithoutHistoryHaveNoBaseline() {
        #expect(PulseFacts.supporters(now: 500, before: nil, period: .lastSevenDays).baseline == nil)
        #expect(PulseFacts.supporters(now: 500, before: 480, period: .lastSevenDays).baseline == 480)
    }
}
