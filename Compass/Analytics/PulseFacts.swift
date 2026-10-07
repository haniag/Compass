//
//  PulseFacts.swift
//  Compass
//
//  Builds the Facts shown on Pulse from raw service results.
//

import Foundation

nonisolated enum PulseFacts {
    /// `before` is the count one period ago (7 days ago for "Last 7 days").
    static func supporters(now: Int, before: Int?, period: Fact.Period) -> Fact {
        Fact(metric: .supporters, unit: .count, value: Decimal(now), baseline: before.map { Decimal($0) }, period: period)
    }

    static func newJoins(current: Int, previous: Int, period: Fact.Period) -> Fact {
        Fact(metric: .newJoins, unit: .count, value: Decimal(current), baseline: Decimal(previous), period: period)
    }

    /// Raised and average gift in the reporting currency. Gifts in other currencies
    /// aren't counted here (they're for the Giving tab). Raised is 0 when none came in.
    static func giving(current: [ENDonationAmount], previous: [ENDonationAmount], currency: String,
                       period: Fact.Period) -> [Fact] {
        let now = current.first { $0.currency == currency }
        let before = previous.first { $0.currency == currency }

        var facts = [Fact(metric: .raised, unit: .money(currencyCode: currency),
                          value: now?.total ?? 0, baseline: before?.total ?? 0, period: period)]
        if let now, now.total > 0 {
            let baseline = before.flatMap { $0.total > 0 ? $0.average : nil }
            facts.append(Fact(metric: .averageGift, unit: .money(currencyCode: currency),
                              value: now.average, baseline: baseline, period: period))
        }
        return facts
    }

    /// Nil when no emails went out in the period.
    static func emailOpenRate(current: ENBroadcastStats, previous: ENBroadcastStats, period: Fact.Period) -> Fact? {
        guard let rate = current.openRate else { return nil }
        return Fact(metric: .emailOpenRate, unit: .percent, value: rate, baseline: previous.openRate, period: period)
    }
}
