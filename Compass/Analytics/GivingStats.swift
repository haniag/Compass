//
//  GivingStats.swift
//  Compass
//
//  One donation page's gifts in a window of days, in the reporting currency.
//  Pure functions; no wording here.
//

import Foundation

nonisolated enum GivingStats {
    struct Summary: Hashable, Sendable {
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

    /// "▲ 8%" for raised against the window before. Nil when nothing came in before.
    static func change(_ current: Summary, from previous: Summary) -> FactChange? {
        FactChange.percent(from: previous.raised, to: current.raised, higherIsBetter: true)
    }
}
