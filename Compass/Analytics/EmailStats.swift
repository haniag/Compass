//
//  EmailStats.swift
//  Compass
//
//  Email numbers worked out from individual sends: rates over a window of days, the
//  best day of the week to send, and sends that lost more supporters than usual.
//  Pure functions; no wording here.
//

import Foundation

nonisolated enum EmailStats {
    /// Sends smaller than this are left out of unsubscribe checks: one unsubscribe
    /// from a 20-person test send isn't a signal.
    static let minimumSendSize = 200
    /// The usual unsubscribe rate needs at least this many sends to mean anything.
    static let minimumSendsForUsual = 5
    /// A send lost "more supporters than usual" at this many times the usual rate…
    static let highUnsubscribeFactor: Decimal = 2
    /// …and at no less than this rate (percent), so a near-zero usual rate doesn't flag every send.
    static let minimumHighUnsubscribeRate = Decimal(string: "0.2")!
    /// The list-fatigue alert needs this many of the newest sends to all be high.
    static let fatigueSendCount = 3

    // MARK: Totals and rates

    /// Emails sent, opened, clicked and unsubscribed, added up over some sends.
    struct Totals: Hashable, Sendable {
        var sends = 0
        var sent = 0
        var opens = 0
        var clicks = 0
        var unsubscribes = 0

        init(_ broadcasts: some Sequence<ENBroadcast>) {
            for broadcast in broadcasts {
                sends += 1
                sent += broadcast.sent
                // EN sometimes counts more opens or clicks than emails sent (3 opens from
                // 2 emails, a click on a send of 0). Cap each at the number sent, so no
                // rate goes over 100%.
                opens += min(broadcast.opens, broadcast.sent)
                clicks += min(broadcast.clicks, broadcast.sent)
                unsubscribes += min(broadcast.unsubscribes, broadcast.sent)
            }
        }

        /// Percent of all emails sent, so a big send counts for more than a small one.
        /// Nil when nothing was sent.
        var openRate: Decimal? { percent(of: opens) }
        var clickRate: Decimal? { percent(of: clicks) }
        var unsubscribeRate: Decimal? { percent(of: unsubscribes) }

        private func percent(of count: Int) -> Decimal? {
            sent > 0 ? Decimal(count) / Decimal(sent) * 100 : nil
        }
    }

    /// Opens, clicks and unsubscribes for sends in `period`, each compared with the same
    /// number of days before. Empty when nothing was sent in `period`.
    static func rates(_ broadcasts: [ENBroadcast], in period: DayRange, calendar: Calendar = .current) -> [EmailRate] {
        let before = period.previous(calendar: calendar)
        let now = Totals(broadcasts.filter { period.contains($0.sentOn, calendar: calendar) })
        let then = Totals(broadcasts.filter { before.contains($0.sentOn, calendar: calendar) })
        return [
            now.openRate.map { EmailRate(kind: .opens, value: $0, baseline: then.openRate) },
            now.clickRate.map { EmailRate(kind: .clicks, value: $0, baseline: then.clickRate) },
            now.unsubscribeRate.map { EmailRate(kind: .unsubscribes, value: $0, baseline: then.unsubscribeRate) },
        ].compactMap { $0 }
    }

    // MARK: Best day to send

    /// A day can be named "best" only with at least this many sends on it. Clicks are
    /// rarer than opens, so one or two sends say little.
    static let minimumSendsForBestDay = 3

    struct WeekdayRate: Identifiable, Hashable, Sendable {
        /// 1 = Sunday … 7 = Saturday, as in Calendar.
        let weekday: Int
        let sends: Int
        /// Click rate (CTR): total clicks ÷ total emails sent that day of the week.
        /// Nil for a day with no sends.
        let clickRate: Decimal?

        var id: Int { weekday }
    }

    /// Click rate for each day of the week, all seven days, in the calendar's own order
    /// (Sunday or Monday first, depending on the region). Clicks, not opens: Apple Mail
    /// and some spam filters open every email automatically, so opens overstate readers.
    static func clickRateByWeekday(_ broadcasts: [ENBroadcast], calendar: Calendar = .current) -> [WeekdayRate] {
        let byWeekday = Dictionary(grouping: broadcasts) { calendar.component(.weekday, from: $0.sentOn) }
        return (0..<7).map { offset in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            let totals = Totals(byWeekday[weekday] ?? [])
            return WeekdayRate(weekday: weekday, sends: totals.sends, clickRate: totals.clickRate)
        }
    }

    /// The day with the highest click rate, counting only days with 3 or more sends.
    /// Nil until sends are spread over at least 3 days of the week.
    static func bestWeekday(_ days: [WeekdayRate]) -> Int? {
        guard days.filter({ $0.sends > 0 }).count >= 3 else { return nil }
        let candidates = days.filter { $0.sends >= minimumSendsForBestDay }
            .compactMap { day in day.clickRate.map { (weekday: day.weekday, rate: $0) } }
        // max(by:) keeps the first of equal days.
        return candidates.max { $0.rate < $1.rate }?.weekday
    }

    // MARK: Unsubscribes

    /// The typical unsubscribe rate of one send: the middle value (median) of the sends
    /// big enough to count, so one bad send doesn't move it. Nil with too few sends.
    static func usualUnsubscribeRate(_ broadcasts: [ENBroadcast]) -> Decimal? {
        let rates = broadcasts
            .filter { $0.sent >= minimumSendSize }
            .compactMap { Totals([$0]).unsubscribeRate }
            .sorted()
        guard rates.count >= minimumSendsForUsual else { return nil }
        let middle = rates.count / 2
        return rates.count.isMultiple(of: 2) ? (rates[middle - 1] + rates[middle]) / 2 : rates[middle]
    }

    /// True when a send lost supporters at twice the usual rate or more.
    static func hasHighUnsubscribes(_ broadcast: ENBroadcast, usual: Decimal?) -> Bool {
        guard let usual, broadcast.sent >= minimumSendSize,
              let rate = Totals([broadcast]).unsubscribeRate
        else { return false }
        return rate >= max(usual * highUnsubscribeFactor, minimumHighUnsubscribeRate)
    }

    /// Several sends in a row that lost supporters faster than usual.
    struct Fatigue: Hashable, Sendable {
        let sends: Int
        /// Their combined unsubscribe rate ÷ the usual rate, rounded: 3 means "about 3 times".
        let timesUsual: Int
    }

    /// List fatigue: each of the newest 3 sends (big enough to count) had high unsubscribes.
    static func listFatigue(_ broadcasts: [ENBroadcast]) -> Fatigue? {
        guard let usual = usualUnsubscribeRate(broadcasts), usual > 0 else { return nil }
        let newest = broadcasts
            .filter { $0.sent >= minimumSendSize }
            .sorted { $0.sentOn > $1.sentOn }
            .prefix(fatigueSendCount)
        guard newest.count == fatigueSendCount,
              newest.allSatisfy({ hasHighUnsubscribes($0, usual: usual) }),
              let combined = Totals(newest).unsubscribeRate
        else { return nil }
        let times = NSDecimalNumber(decimal: combined / usual).doubleValue
        return Fatigue(sends: fatigueSendCount, timesUsual: Int(times.rounded()))
    }
}
