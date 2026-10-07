//
//  PulseViewModel.swift
//  Compass
//
//  Pulse (home): supporters, and the last 7 days vs the 7 days before.
//

import Foundation
import Observation
import SwiftData

@Observable
final class PulseViewModel {
    /// Weeks of supporter history in the trend line.
    static let trendWeeks = 12
    /// Don't re-fetch on every visit; pull to refresh is always available.
    private static let staleAfter: TimeInterval = 30 * 60

    private(set) var period = DayRange.lastSevenDays(before: .now)
    private(set) var supporters: Fact?
    /// The weekly tiles, in display order. A tile whose service failed is simply missing.
    private(set) var weeklyFacts: [Fact] = []
    private(set) var supporterTrend: [SupporterTrend.Point] = []
    private(set) var topInsight: Insight?
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing = false
    /// True when the last refresh got nothing back at all (e.g. offline).
    private(set) var refreshFailed = false

    private let credentials: ENCredentials
    private let client: ENClient

    init(credentials: ENCredentials) {
        self.credentials = credentials
        client = ENClient(credentials: credentials)
    }

    var hasData: Bool { supporters != nil || !weeklyFacts.isEmpty }

    /// Supporters plus the weekly facts: what Insights is written from.
    var allFacts: [Fact] { [supporters].compactMap { $0 } + weeklyFacts }

    /// "Sep 17 – 23 · Updated 8:02 AM"
    var subtitle: String {
        guard let lastUpdated else { return period.label }
        let time = Calendar.current.isDateInToday(lastUpdated)
            ? lastUpdated.formatted(date: .omitted, time: .shortened)
            : lastUpdated.formatted(.dateTime.month(.abbreviated).day())
        return "\(period.label) · Updated \(time)"
    }

    // MARK: Loading

    func refreshIfStale(in context: ModelContext) async {
        if let lastUpdated, Date.now.timeIntervalSince(lastUpdated) < Self.staleAfter { return }
        await refresh(in: context)
    }

    func refresh(in context: ModelContext) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date.now
        let thisWeek = DayRange.lastSevenDays(before: now)
        let weekBefore = thisWeek.previous()

        #if DEBUG
        if credentials.isDemo {
            SupporterSnapshot.seedDemoHistoryIfEmpty(in: context, now: now)
        }
        #endif

        // All at once; ENClient keeps it to 4 requests in flight. A failed call becomes nil.
        async let count = try? client.supporterCount()
        async let joinsNow = try? client.newJoins(from: thisWeek.firstDay, through: thisWeek.lastDay)
        async let joinsBefore = try? client.newJoins(from: weekBefore.firstDay, through: weekBefore.lastDay)
        async let givingNow = try? client.donationAmounts(from: thisWeek.firstDay, through: thisWeek.lastDay)
        async let givingBefore = try? client.donationAmounts(from: weekBefore.firstDay, through: weekBefore.lastDay)
        async let emailNow = try? client.broadcastStats(from: thisWeek.firstDay, through: thisWeek.lastDay)
        async let emailBefore = try? client.broadcastStats(from: weekBefore.firstDay, through: weekBefore.lastDay)

        let supporterCount = await count
        var facts: [Fact] = []
        if let now = await joinsNow, let before = await joinsBefore {
            facts.append(PulseFacts.newJoins(current: now, previous: before))
        }
        if let now = await givingNow, let before = await givingBefore {
            facts += PulseFacts.giving(current: now, previous: before, currency: AccountSettings.reportingCurrency)
        }
        if let now = await emailNow, let before = await emailBefore,
           let openRate = PulseFacts.emailOpenRate(current: now, previous: before) {
            facts.append(openRate)
        }

        guard supporterCount != nil || !facts.isEmpty else {
            // Keep whatever was showing before and say so.
            refreshFailed = true
            return
        }

        if let supporterCount {
            SupporterSnapshot.record(supporterCount, at: now, in: context)
        }
        let history = SupporterSnapshot.recent(weeks: Self.trendWeeks, before: now, in: context)
            .map { SupporterTrend.Point(date: $0.takenAt, count: $0.count) }
        let weekAgo = SupporterTrend.count(atOrBefore: now.addingTimeInterval(-7 * 86_400), in: history)

        period = thisWeek
        supporters = supporterCount.map { PulseFacts.supporters(now: $0, weekAgo: weekAgo) }
        supporterTrend = SupporterTrend.weekly(history, weeks: Self.trendWeeks, now: now)
        weeklyFacts = facts
        topInsight = TemplateInsights.pulse(facts: facts)
        lastUpdated = now
        refreshFailed = false
    }
}
