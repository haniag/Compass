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
}
