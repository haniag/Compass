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

    /// The time period Pulse shows, picked by the user. Days are complete days, so
    /// today is never included.
    enum Period: String, CaseIterable, Identifiable, Hashable, Sendable {
        /// Yesterday vs the day before.
        case yesterday
        /// Last 7 days vs the 7 days before.
        case lastSevenDays
        /// Last 30 days vs the 30 days before.
        case lastThirtyDays
        /// Last calendar month vs the month before it (September vs August).
        case lastMonth

        var id: Self { self }
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
