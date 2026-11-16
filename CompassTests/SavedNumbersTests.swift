//
//  SavedNumbersTests.swift
//  CompassTests
//
//  Keeping the last loaded numbers on the device.
//

import Foundation
import SwiftData
import Testing
@testable import Compass

@MainActor
struct SavedNumbersTests {
    private let context: ModelContext

    init() throws {
        let container = try ModelContainer(for: SavedNumbers.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
    }

    @Test func givesBackWhatWasSaved() {
        let facts = [
            Fact(metric: .raised, unit: .money(currencyCode: "USD"), value: 1250.5, baseline: 900, period: .lastSevenDays),
            Fact(metric: .emailOpenRate, unit: .percent, value: 38.2, baseline: nil, period: .lastSevenDays),
        ]
        let savedAt = Date(timeIntervalSince1970: 1_790_000_000)
        SavedNumbers.save(facts, as: "pulse.test", at: savedAt, in: context)

        let loaded = SavedNumbers.load([Fact].self, key: "pulse.test", in: context)
        #expect(loaded?.value == facts)
        #expect(loaded?.savedAt == savedAt)
    }

    @Test func savingAgainReplacesTheEarlierEntry() {
        SavedNumbers.save([1, 2], as: "numbers", in: context)
        SavedNumbers.save([3], as: "numbers", in: context)

        #expect(SavedNumbers.load([Int].self, key: "numbers", in: context)?.value == [3])
        #expect((try? context.fetchCount(FetchDescriptor<SavedNumbers>())) == 1)
    }

    @Test func nothingSavedOrADifferentShapeGivesNil() {
        #expect(SavedNumbers.load([Int].self, key: "missing", in: context) == nil)
        SavedNumbers.save(["a"], as: "words", in: context)
        #expect(SavedNumbers.load([Int].self, key: "words", in: context) == nil)
    }

    @Test func dailyTotalsKeepTheirDaysAndAmounts() {
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        let totals: [Date: Decimal] = [day: 120.75, day.addingTimeInterval(86_400): 0]
        SavedNumbers.save(totals, as: "giving.daily.1", in: context)
        #expect(SavedNumbers.load([Date: Decimal].self, key: "giving.daily.1", in: context)?.value == totals)
    }

    // MARK: Pulse briefing

    private static let briefingFacts = [
        PulseFacts.supporters(now: 48_312, before: 48_098, period: .lastSevenDays),
        Fact(metric: .newJoins, unit: .count, value: 386, baseline: 342, period: .lastSevenDays),
    ]

    @Test func sameFactsReuseTheSavedBriefing() {
        SavedBriefing.save("You welcomed 386 new supporters.", facts: Self.briefingFacts, in: context)
        #expect(SavedBriefing.text(for: Self.briefingFacts, in: context) == "You welcomed 386 new supporters.")
    }

    @Test func changedFactsDontReuseTheSavedBriefing() {
        SavedBriefing.save("You welcomed 386 new supporters.", facts: Self.briefingFacts, in: context)

        var changed = Self.briefingFacts
        changed[1] = Fact(metric: .newJoins, unit: .count, value: 390, baseline: 342, period: .lastSevenDays)
        #expect(SavedBriefing.text(for: changed, in: context) == nil)
        // One figure fewer (a service failed) is different numbers too.
        #expect(SavedBriefing.text(for: [Self.briefingFacts[0]], in: context) == nil)
        // The same figures for another period are another briefing.
        let otherPeriod = [Fact(metric: .newJoins, unit: .count, value: 386, baseline: 342, period: .lastThirtyDays)]
        #expect(SavedBriefing.text(for: otherPeriod, in: context) == nil)
    }

    @Test func eachPeriodKeepsItsOwnBriefing() {
        let month = [Fact(metric: .newJoins, unit: .count, value: 1_200, baseline: 1_100, period: .lastMonth)]
        SavedBriefing.save("Seven days.", facts: Self.briefingFacts, in: context)
        SavedBriefing.save("Last month.", facts: month, in: context)
        #expect(SavedBriefing.text(for: Self.briefingFacts, in: context) == "Seven days.")
        #expect(SavedBriefing.text(for: month, in: context) == "Last month.")
    }
}

struct WidgetSnapshotTests {
    @Test func carriesEachNumberAsTextWithItsChange() {
        let facts = [
            PulseFacts.supporters(now: 48_312, before: 48_098, period: .lastSevenDays),
            Fact(metric: .emailOpenRate, unit: .percent, value: 38.2, baseline: 39.6, period: .lastSevenDays),
            PulseFacts.supporters(now: 10, before: nil, period: .lastSevenDays),
        ]
        let snapshot = WidgetSnapshot(period: .lastSevenDays, facts: facts, updatedAt: .now)
        #expect(snapshot.periodTitle == "Last 7 days")
        #expect(snapshot.items[0] == .init(title: "Supporters", value: "48,312", change: "▲ 214", isGood: true))
        #expect(snapshot.items[1] == .init(title: "Email opens", value: "38.2%", change: "▼ 1.4 pts", isGood: false))
        #expect(snapshot.items[2].change == nil)
    }
}
