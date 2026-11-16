//
//  EmailFindings.swift
//  Compass
//
//  What the Email tab's summary card may talk about, worked out from the sends:
//  the three rates, list fatigue, the best email, an email that lost more supporters
//  than usual, and the best day to send. Pure functions; the wording is in
//  Insights/EmailSummary.swift.
//

import Foundation

nonisolated struct EmailFindings: Hashable, Sendable {
    /// One email the summary may mention by name, with the rate that makes it stand out.
    struct NamedSend: Hashable, Sendable {
        let name: String
        /// Percent: 4.1 means 4.1%.
        let rate: Decimal
    }

    /// "Best email" needs at least this many emails to choose from.
    static let minimumSendsForBest = 3
    /// Longer names are left out: they'd crowd a two-sentence summary.
    static let longestName = 60

    /// Opens, clicks and unsubscribes over the window, each against the window before. Never empty.
    let rates: [EmailRate]
    /// How many emails went out in the window.
    let sendsInPeriod: Int
    let fatigue: EmailStats.Fatigue?
    /// The email in the window with the highest click rate.
    let bestSend: NamedSend?
    /// The newest email in the window that lost supporters at twice the usual rate or more.
    let highUnsubscribeSend: NamedSend?
    /// The best day of the week to send, by click rate.
    let bestWeekday: EmailStats.WeekdayRate?

    /// Nil when nothing was sent in `period`: there's nothing to summarize.
    /// `sends` is everything the Email tab loaded (90 days), in any order.
    static func make(from sends: [ENBroadcast], in period: DayRange, calendar: Calendar = .current) -> EmailFindings? {
        let rates = EmailStats.rates(sends, in: period, calendar: calendar)
        guard !rates.isEmpty else { return nil }

        let inPeriod = sends
            .filter { period.contains($0.sentOn, calendar: calendar) }
            .sorted { $0.sentOn > $1.sentOn }
        // Small sends (tests, seed lists) have rates that mean little.
        let countable = inPeriod.filter { $0.sent >= EmailStats.minimumSendSize }

        var bestSend: NamedSend?
        if countable.count >= minimumSendsForBest {
            let ranked = countable.compactMap { send in
                EmailStats.Totals([send]).clickRate.map { (send: send, rate: $0) }
            }
            // max(by:) keeps the first of equal emails, which is the newest.
            if let best = ranked.max(by: { $0.rate < $1.rate }), best.rate > 0 {
                bestSend = named(best.send, rate: best.rate)
            }
        }

        let usual = EmailStats.usualUnsubscribeRate(sends)
        let highUnsubscribeSend = countable
            .first { EmailStats.hasHighUnsubscribes($0, usual: usual) }
            .flatMap { send in EmailStats.Totals([send]).unsubscribeRate.flatMap { named(send, rate: $0) } }

        let weekdays = EmailStats.clickRateByWeekday(sends, calendar: calendar)
        let bestWeekday = EmailStats.bestWeekday(weekdays).flatMap { day in weekdays.first { $0.weekday == day } }

        return EmailFindings(
            rates: rates,
            sendsInPeriod: inPeriod.count,
            fatigue: EmailStats.listFatigue(sends),
            bestSend: bestSend,
            highUnsubscribeSend: highUnsubscribeSend,
            bestWeekday: bestWeekday
        )
    }

    /// Nil when the name can't be quoted safely: empty, very long, or with quotation
    /// marks of its own (the summary puts names inside quotation marks).
    private static func named(_ send: ENBroadcast, rate: Decimal) -> NamedSend? {
        let name = send.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= longestName,
              !name.contains(where: { "\"“”".contains($0) })
        else { return nil }
        return NamedSend(name: name, rate: rate)
    }
}
