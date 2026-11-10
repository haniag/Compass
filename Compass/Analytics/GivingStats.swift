//
//  GivingStats.swift
//  Compass
//
//  One donation page's gifts in a window of days, in the reporting currency.
//  Pure functions; no wording here.
//

import Foundation

nonisolated enum GivingStats {
    struct Summary: Hashable, Sendable, Codable {
        let currency: String
        let raised: Decimal
        /// All gifts, in every currency.
        let gifts: Int
        let single: Decimal
        let singleGifts: Int
        let recurring: Decimal
        let recurringGifts: Int
        /// True when some gifts came in other currencies. They aren't in the amounts above.
        let hasOtherCurrencies: Bool

        /// `giving` is nil when EN had no gifts for the window.
        init(_ giving: ENPageGiving?, currency: String) {
            self.currency = currency
            raised = giving?.raised[currency] ?? 0
            gifts = giving?.gifts ?? 0
            single = giving?.raisedSingle[currency] ?? 0
            singleGifts = giving?.singleGifts ?? 0
            recurring = giving?.raisedRecurring[currency] ?? 0
            recurringGifts = giving?.recurringGifts ?? 0
            hasOtherCurrencies = giving?.raised.contains { $0.key != currency && $0.value > 0 } ?? false
        }

        /// Raised ÷ gifts. Nil with no gifts or nothing raised (free event tickets count as
        /// gifts), or when some came in other currencies (the count would include gifts
        /// the amount leaves out).
        var averageGift: Decimal? {
            guard gifts > 0, raised > 0, !hasOtherCurrencies else { return nil }
            return raised / Decimal(gifts)
        }

        /// The one-time share of the money raised, 0…1. Nil when nothing was raised.
        var singleShare: Double? {
            guard raised > 0 else { return nil }
            return NSDecimalNumber(decimal: single / raised).doubleValue
        }
    }

    /// One bar of the daily-total chart: what a page raised on one day, in the reporting currency.
    struct DailyTotal: Hashable, Sendable, Codable {
        /// Start of the day, in the user's calendar.
        let day: Date
        let raised: Decimal
    }

    /// The day that raised the most (the earlier one on a tie). Nil when nothing was raised.
    static func bestDay(_ days: [DailyTotal]) -> DailyTotal? {
        days.reduce(nil as DailyTotal?) { best, day in
            day.raised > (best?.raised ?? 0) ? day : best
        }
    }

    /// What one page raised, for the list of all followed pages.
    struct PageTotal: Hashable, Sendable, Identifiable {
        let pageId: Int
        let name: String
        let raised: Decimal

        var id: Int { pageId }
    }

    /// Biggest first; pages that raised the same are in name order.
    static func ranked(_ pages: [PageTotal]) -> [PageTotal] {
        pages.sorted { ($0.raised, $1.name) > ($1.raised, $0.name) }
    }

    static func combined(_ pages: [PageTotal]) -> Decimal {
        pages.reduce(0) { $0 + $1.raised }
    }

    /// "▲ 8%" for raised against the window before. Nil when nothing came in before.
    static func change(_ current: Summary, from previous: Summary) -> FactChange? {
        FactChange.percent(from: previous.raised, to: current.raised, higherIsBetter: true)
    }
}
