//
//  GivingFindings.swift
//  Compass
//
//  What the "All pages" summary on Giving may talk about: what the followed pages
//  raised together, which one raised the most, and any that raised nothing.
//  Pure functions; the wording is in Insights/GivingSummary.swift.
//

import Foundation

nonisolated struct GivingFindings: Hashable, Sendable {
    /// 7 or 30, or nil for the whole campaign.
    let days: Int?
    let currency: String
    let pageCount: Int
    /// Raised by all the pages together. Always more than zero.
    let total: Decimal
    /// The page that raised the most.
    let top: GivingStats.PageTotal
    /// Pages that raised nothing in the last 7 or 30 days. Always empty for the whole
    /// campaign: a page with nothing yet may simply be new.
    let quiet: [GivingStats.PageTotal]

    /// Nil with fewer than two pages or when nothing was raised: there's nothing to compare.
    static func make(pages: [GivingStats.PageTotal], days: Int?, currency: String) -> GivingFindings? {
        let ranked = GivingStats.ranked(pages)
        let total = GivingStats.combined(pages)
        guard ranked.count >= 2, total > 0, let top = ranked.first else { return nil }
        return GivingFindings(
            days: days,
            currency: currency,
            pageCount: ranked.count,
            total: total,
            top: top,
            quiet: days == nil ? [] : ranked.filter { $0.raised == 0 }
        )
    }
}
