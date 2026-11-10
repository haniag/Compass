//
//  PulseSummary.swift
//  Compass
//
//  Pulse as a few lines of plain text, for the Share button: to paste into an email
//  or a message to the Executive Director or the board. Totals only, no supporter data.
//

import Foundation

nonisolated enum PulseSummary {
    /// `headline` is the briefing or top insight; left out when nil.
    ///
    ///     How we did: last 7 days (Nov 3 – 9)
    ///
    ///     Giving rose and more people joined.
    ///
    ///     • Supporters: 48,312 (▲ 214 vs 7 days ago)
    ///     • Raised: $23,480 (▲ 13% vs the 7 days before)
    static func text(period: Fact.Period, range: DayRange, headline: String?, facts: [Fact]) -> String {
        var parts = ["How we did: \(period.title.lowercased()) (\(range.label))"]
        if let headline, !headline.isEmpty {
            parts.append(headline)
        }
        let lines = facts.map { fact in
            guard let change = fact.change else {
                return "• \(fact.displayName): \(fact.formattedValue)"
            }
            let comparedWith = fact.metric == .supporters ? fact.period.spanAgo : fact.period.before
            return "• \(fact.displayName): \(fact.formattedValue) (\(change.badgeText) vs \(comparedWith))"
        }
        if !lines.isEmpty {
            parts.append(lines.joined(separator: "\n"))
        }
        return parts.joined(separator: "\n\n")
    }
}
