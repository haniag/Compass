//
//  PulseFacts.swift
//  Compass
//
//  Builds the Facts shown on Pulse from raw service results.
//

import Foundation

nonisolated enum PulseFacts {
    static func supporters(now: Int, weekAgo: Int?) -> Fact {
        Fact(metric: .supporters, unit: .count, value: Decimal(now), baseline: weekAgo.map { Decimal($0) }, period: .lastSevenDays)
    }

    static func newJoins(current: Int, previous: Int) -> Fact {
        Fact(metric: .newJoins, unit: .count, value: Decimal(current), baseline: Decimal(previous), period: .lastSevenDays)
    }

    /// Raised and average gift in the reporting currency. Gifts in other currencies
    /// aren't counted here (they're for the Giving tab). Raised is 0 when none came in.
    static func giving(current: [ENDonationAmount], previous: [ENDonationAmount], currency: String) -> [Fact] {
        let now = current.first { $0.currency == currency }
        let before = previous.first { $0.currency == currency }

        var facts = [Fact(metric: .raised, unit: .money(currencyCode: currency),
                          value: now?.total ?? 0, baseline: before?.total ?? 0, period: .lastSevenDays)]
        if let now, now.total > 0 {
            let baseline = before.flatMap { $0.total > 0 ? $0.average : nil }
            facts.append(Fact(metric: .averageGift, unit: .money(currencyCode: currency),
                              value: now.average, baseline: baseline, period: .lastSevenDays))
        }
        return facts
    }

    /// Nil when no emails went out in the last 7 days.
    static func emailOpenRate(current: ENBroadcastStats, previous: ENBroadcastStats) -> Fact? {
        guard let rate = current.openRate else { return nil }
        return Fact(metric: .emailOpenRate, unit: .percent, value: rate, baseline: previous.openRate, period: .lastSevenDays)
    }
}
