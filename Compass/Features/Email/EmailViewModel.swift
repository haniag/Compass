//
//  EmailViewModel.swift
//  Compass
//
//  Email tab: how sends did over the last 30 days, each recent send, and the best day to send.
//

import Foundation
import Observation

@Observable
final class EmailViewModel {
    /// Rates compare this many complete days with the same number of days before.
    static let windowDays = 30
    /// Sends this far back feed the usual unsubscribe rate and the best day to send.
    static let historyDays = 90
    /// How many of the newest sends are listed.
    static let recentSendCount = 10
    /// Don't re-fetch on every visit; pull to refresh is always available.
    private static let staleAfter: TimeInterval = 30 * 60

    private(set) var period = DayRange.last(windowDays, daysBefore: .now)
    /// Opens, clicks and unsubscribes in `period`. Empty when nothing was sent in it.
    private(set) var rates: [EmailRate] = []
    private(set) var sendsInPeriod = 0
    /// Newest first.
    private(set) var recentSends: [ENBroadcast] = []
    private(set) var weekdays: [EmailStats.WeekdayRate] = []
    private(set) var bestWeekday: Int?
    private(set) var fatigue: EmailStats.Fatigue?
    private(set) var hasLoaded = false
    private(set) var isRefreshing = false
    /// Why the last refresh failed, in plain words. Nil when it worked.
    private(set) var errorMessage: String?

    private var usualUnsubscribeRate: Decimal?
    private var lastUpdated: Date?
    private let client: ENClient

    init(credentials: ENCredentials) {
        client = ENClient(credentials: credentials)
    }

    /// "Last 30 days · 9 sends"
    var subtitle: String {
        let sends = sendsInPeriod == 1 ? "1 send" : "\(sendsInPeriod) sends"
        return "Last \(Self.windowDays) days · \(sends)"
    }

    /// The best day's entry, for the chart caption.
    var best: EmailStats.WeekdayRate? {
        weekdays.first { $0.weekday == bestWeekday }
    }

    func hasHighUnsubscribes(_ send: ENBroadcast) -> Bool {
        EmailStats.hasHighUnsubscribes(send, usual: usualUnsubscribeRate)
    }

    // MARK: Loading

    func refreshIfStale() async {
        if let lastUpdated, Date.now.timeIntervalSince(lastUpdated) < Self.staleAfter { return }
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date.now
        let today = Calendar.current.startOfDay(for: now)
        let firstDay = Calendar.current.date(byAdding: .day, value: -Self.historyDays, to: today) ?? today

        let sends: [ENBroadcast]
        do {
            sends = try await client.broadcasts(since: firstDay).sorted { $0.sentOn > $1.sentOn }
        } catch {
            // Keep whatever was showing before and say so.
            errorMessage = error.userMessage
            return
        }

        let period = DayRange.last(Self.windowDays, daysBefore: now)
        self.period = period
        rates = EmailStats.rates(sends, in: period)
        sendsInPeriod = sends.filter { period.contains($0.sentOn) }.count
        recentSends = Array(sends.prefix(Self.recentSendCount))
        weekdays = EmailStats.clickRateByWeekday(sends)
        bestWeekday = EmailStats.bestWeekday(weekdays)
        usualUnsubscribeRate = EmailStats.usualUnsubscribeRate(sends)
        fatigue = EmailStats.listFatigue(sends)
        lastUpdated = now
        hasLoaded = true
        errorMessage = nil
    }
}
