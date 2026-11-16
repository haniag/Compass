//
//  EmailViewModel.swift
//  Compass
//
//  Email tab: how sends did over the last 30 days, each recent send, and the best day to send.
//

import Foundation
import Observation
import SwiftData

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
    /// What the summary card talks about. Nil when nothing was sent in `period`.
    private(set) var findings: EmailFindings?
    /// Apple Intelligence's two-sentence summary. Nil without it, or when it broke the
    /// rules; the card then shows `findings.template`.
    private(set) var summary: String?
    private(set) var isWritingSummary = false
    private(set) var hasLoaded = false
    private(set) var isRefreshing = false
    /// Why the last refresh failed, in plain words. Nil when it worked.
    private(set) var errorMessage: String?

    /// The findings `summary` was written from.
    private var summaryFindings: EmailFindings?
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

    /// Where the last sends are kept on the device, so Email opens with numbers.
    private static let savedKey = "email.sends"

    func refreshIfStale(in context: ModelContext) async {
        if !hasLoaded, let saved = SavedNumbers.load([ENBroadcast].self, key: Self.savedKey, in: context) {
            show(saved.value, asOf: saved.savedAt)
        }
        // Numbers from an earlier day are stale however recent: the 30 days moved on.
        if let lastUpdated, Date.now.timeIntervalSince(lastUpdated) < Self.staleAfter,
           Calendar.current.isDateInToday(lastUpdated) { return }
        await refresh(in: context)
    }

    func refresh(in context: ModelContext) async {
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

        show(sends, asOf: now)
        errorMessage = nil
        SavedNumbers.save(sends, as: Self.savedKey, at: now, in: context)
    }

    /// Works out everything on screen from `sends` (newest first), as things stood at `now`.
    private func show(_ sends: [ENBroadcast], asOf now: Date) {
        let period = DayRange.last(Self.windowDays, daysBefore: now)
        self.period = period
        rates = EmailStats.rates(sends, in: period)
        sendsInPeriod = sends.filter { period.contains($0.sentOn) }.count
        recentSends = Array(sends.prefix(Self.recentSendCount))
        weekdays = EmailStats.clickRateByWeekday(sends)
        bestWeekday = EmailStats.bestWeekday(weekdays)
        usualUnsubscribeRate = EmailStats.usualUnsubscribeRate(sends)
        fatigue = EmailStats.listFatigue(sends)
        findings = EmailFindings.make(from: sends, in: period)
        lastUpdated = now
        hasLoaded = true
    }

    // MARK: Summary

    /// Writes the summary when the numbers change. Cheap to call again with the same numbers.
    func writeSummary() async {
        let findings = self.findings
        guard findings != summaryFindings else { return }
        summary = nil
        // A cancelled earlier run may have left this on.
        isWritingSummary = false
        guard let findings, InsightWriter.status == .available else { return }

        isWritingSummary = true
        let text = await EmailSummaryWriter.summary(from: findings)
        // The numbers changed again, or the screen went away; it'll be written next time.
        guard !Task.isCancelled, findings == self.findings else { return }
        summary = text
        summaryFindings = findings
        isWritingSummary = false
    }
}
