//
//  PulseViewModel.swift
//  Compass
//
//  Pulse (home): supporters, and the chosen period (yesterday, the last 7 or 30 days,
//  or last month) vs the same span before it.
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
    private static let periodKey = "pulse.period"

    /// The period the user picked. Remembered between launches; changing it doesn't
    /// load anything by itself, the view calls `refresh`.
    var selectedPeriod = Fact.Period(rawValue: UserDefaults.standard.string(forKey: periodKey) ?? "") ?? .lastSevenDays {
        didSet { UserDefaults.standard.set(selectedPeriod.rawValue, forKey: Self.periodKey) }
    }
    /// The period of the numbers on screen. Lags `selectedPeriod` while a new one loads.
    private(set) var shownPeriod = Fact.Period.lastSevenDays
    /// The days the numbers on screen cover.
    private(set) var period = DayRange.lastSevenDays(before: .now)
    private(set) var supporters: Fact?
    /// The period tiles, in display order. A tile whose service failed is simply missing.
    private(set) var weeklyFacts: [Fact] = []
    private(set) var supporterTrend: [SupporterTrend.Point] = []
    private(set) var topInsight: Insight?
    /// Apple Intelligence's two-sentence briefing. Nil without it, or when it broke the rules;
    /// the card then shows `topInsight`.
    private(set) var briefing: String?
    private(set) var isWritingBriefing = false
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing = false
    /// True when the last refresh got nothing back at all (e.g. offline).
    private(set) var refreshFailed = false

    private let credentials: ENCredentials
    private let client: ENClient
    private var briefingFacts: [Fact]?

    init(credentials: ENCredentials) {
        self.credentials = credentials
        client = ENClient(credentials: credentials)
    }

    var hasData: Bool { supporters != nil || !weeklyFacts.isEmpty }

    /// Supporters plus the period facts: what Insights is written from.
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
        if let lastUpdated, Date.now.timeIntervalSince(lastUpdated) < Self.staleAfter,
           shownPeriod == selectedPeriod { return }
        await refresh(in: context)
    }

    func refresh(in context: ModelContext) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // If the user picks another period while this one loads, load that one too.
        var loading: Fact.Period
        repeat {
            loading = selectedPeriod
            guard await load(loading, in: context) else { return }
        } while loading != selectedPeriod
    }

    /// False when nothing came back at all; the numbers already on screen stay.
    private func load(_ chosen: Fact.Period, in context: ModelContext) async -> Bool {
        let now = Date.now
        let current = chosen.range(before: now)
        let before = chosen.comparison(for: current)

        #if DEBUG
        if credentials.isDemo {
            SupporterSnapshot.seedDemoHistoryIfEmpty(in: context, now: now)
        }
        #endif

        // All at once; ENClient keeps it to 4 requests in flight. A failed call becomes nil.
        async let count = try? client.supporterCount()
        async let joinsNow = try? client.newJoins(from: current.firstDay, through: current.lastDay)
        async let joinsBefore = try? client.newJoins(from: before.firstDay, through: before.lastDay)
        async let givingNow = try? client.donationAmounts(from: current.firstDay, through: current.lastDay)
        async let givingBefore = try? client.donationAmounts(from: before.firstDay, through: before.lastDay)
        async let emailNow = try? client.broadcastStats(from: current.firstDay, through: current.lastDay)
        async let emailBefore = try? client.broadcastStats(from: before.firstDay, through: before.lastDay)

        let supporterCount = await count
        var facts: [Fact] = []
        if let now = await joinsNow, let before = await joinsBefore {
            facts.append(PulseFacts.newJoins(current: now, previous: before, period: chosen))
        }
        if let now = await givingNow, let before = await givingBefore {
            facts += PulseFacts.giving(current: now, previous: before, currency: AccountSettings.reportingCurrency,
                                       period: chosen)
        }
        if let now = await emailNow, let before = await emailBefore,
           let openRate = PulseFacts.emailOpenRate(current: now, previous: before, period: chosen) {
            facts.append(openRate)
        }

        guard supporterCount != nil || !facts.isEmpty else {
            // Keep whatever was showing before and say so.
            refreshFailed = true
            return false
        }

        if let supporterCount {
            SupporterSnapshot.record(supporterCount, at: now, in: context)
        }
        let history = SupporterSnapshot.recent(weeks: Self.trendWeeks, before: now, in: context)
            .map { SupporterTrend.Point(date: $0.takenAt, count: $0.count) }
        let supportersBefore = SupporterTrend.count(atOrBefore: chosen.supporterBaselineDate(before: now),
                                                    notBefore: chosen.supporterBaselineEarliest(before: now),
                                                    in: history)

        shownPeriod = chosen
        period = current
        supporters = supporterCount.map { PulseFacts.supporters(now: $0, before: supportersBefore, period: chosen) }
        supporterTrend = SupporterTrend.weekly(history, weeks: Self.trendWeeks, now: now)
        weeklyFacts = facts
        topInsight = TemplateInsights.pulse(facts: facts)
        lastUpdated = now
        refreshFailed = false
        return true
    }

    // MARK: Briefing

    /// Writes the briefing when the numbers change. Cheap to call again with the same numbers.
    func writeBriefing() async {
        let facts = allFacts
        guard facts != briefingFacts else { return }
        briefing = nil
        // A cancelled earlier run may have left this on.
        isWritingBriefing = false
        guard InsightWriter.status == .available, !facts.isEmpty else { return }

        isWritingBriefing = true
        let text = await BriefingWriter.briefing(from: facts)
        // The numbers changed again, or the screen went away; it'll be written next time.
        guard !Task.isCancelled, facts == allFacts else { return }
        briefing = text
        briefingFacts = facts
        isWritingBriefing = false
    }
}
