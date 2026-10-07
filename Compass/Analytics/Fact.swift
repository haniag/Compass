//
//  Fact.swift
//  Compass
//
//  One computed number plus what it's compared against. Screens and insights
//  show figures only from Facts, never from generated text.
//

import Foundation

nonisolated struct Fact: Identifiable, Hashable, Sendable {
    enum Metric: String, Hashable, Sendable {
        case supporters
        case newJoins
        case raised
        case averageGift
        case emailOpenRate
    }

    enum Unit: Hashable, Sendable {
        case count
        case money(currencyCode: String)
        /// A rate already in percent (38.2 means 38.2%). Changes are shown in points.
        case percent
    }

    enum Period: String, Hashable, Sendable {
        /// Last 7 days vs the 7 days before.
        case lastSevenDays
    }

    let metric: Metric
    let unit: Unit
    let value: Decimal
    /// What `value` is compared with (e.g. the week before). Nil when there's nothing to compare.
    let baseline: Decimal?
    let period: Period
    var higherIsBetter = true

    var id: String { "\(metric.rawValue).\(period.rawValue)" }

    /// value − baseline.
    var difference: Decimal? {
        baseline.map { value - $0 }
    }

    /// Relative change in percent (13.0 means +13%). Nil if there's no baseline or it's zero.
    var percentChange: Double? {
        guard let baseline, baseline != 0 else { return nil }
        return NSDecimalNumber(decimal: (value - baseline) / baseline * 100).doubleValue
    }

    var isRate: Bool { unit == .percent }
}
