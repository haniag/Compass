//
//  InsightRules.swift
//  Compass
//
//  Decides which facts are worth talking about. No wording here — see Insights/.
//

import Foundation

nonisolated enum InsightRules {
    /// A rate moving this many points counts the same as a 10% change in a count or amount.
    static let pointsToPercent = 5.0
    /// Smaller moves are treated as a steady week.
    static let minimumScore = 10.0

    /// How big a change is, on one scale for counts, money and rates.
    static func score(_ fact: Fact) -> Double? {
        if fact.isRate {
            return fact.difference.map { abs(NSDecimalNumber(decimal: $0).doubleValue) * pointsToPercent }
        }
        return fact.percentChange.map(abs)
    }

    /// The weekly fact that moved the most, if any moved enough to mention.
    static func pulseHighlight(from facts: [Fact]) -> Fact? {
        highlights(from: facts, limit: 1).first
    }

    /// Weekly facts that moved enough to mention, biggest move first. Supporters is
    /// left out: its weekly change is shown on its own card.
    static func highlights(from facts: [Fact], limit: Int = 4) -> [Fact] {
        let scored = facts
            .filter { $0.metric != .supporters }
            .compactMap { fact in score(fact).map { (fact: fact, score: $0) } }
            .filter { $0.score >= minimumScore }
        // Stable sort, so equal moves keep the order they came in.
        return scored.sorted { $0.score > $1.score }.prefix(limit).map(\.fact)
    }
}
