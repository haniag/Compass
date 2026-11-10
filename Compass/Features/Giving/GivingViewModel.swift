//
//  GivingViewModel.swift
//  Compass
//
//  Giving tab: one donation page's gifts over the last 7 or 30 days (against the
//  days before) or the whole campaign, what it raised each of the last 14 days, and
//  its donors from the last 7 days.
//

import Foundation
import Observation
import SwiftData

@Observable
final class GivingViewModel {
    enum Window: String, CaseIterable, Identifiable, Hashable {
        case lastSevenDays
        case lastThirtyDays
        case campaign

        var id: Self { self }

        var title: String {
            switch self {
            case .lastSevenDays: "7 days"
            case .lastThirtyDays: "30 days"
            case .campaign: "Campaign"
            }
        }

        /// Nil for the whole campaign.
        var days: Int? {
            switch self {
            case .lastSevenDays: 7
            case .lastThirtyDays: 30
            case .campaign: nil
            }
        }
    }

    /// A followed page with a page ID, so Giving can ask about it.
    struct Page: Identifiable, Hashable {
        let pageId: Int
        let campaignId: Int
        let name: String
        /// True when the user set a goal: Giving then also loads what the goal card needs.
        var hasGoal = false

        var id: Int { pageId }
    }

    /// What the goal card is worked out from, whatever time span is picked.
    struct GoalFigures: Hashable {
        /// Raised since the campaign began.
        let raised: Decimal
        /// Raised over the last 7 complete days.
        let recentRaised: Decimal
    }

    nonisolated struct Numbers: Hashable, Codable {
        let current: GivingStats.Summary
        /// The same number of days just before. Nil for the whole campaign.
        let previous: GivingStats.Summary?
    }

    /// Don't re-fetch on every visit; pull to refresh is always available.
    private static let staleAfter: TimeInterval = 30 * 60
    /// "Since the campaign began": EN needs a start date, and accepts one this early.
    private static let campaignStart = DateComponents(calendar: .current, year: 2000, month: 1, day: 1).date ?? .distantPast
    /// Days in the daily-total chart, today included.
    static let chartDays = 14

    private(set) var pages: [Page] = []
    var selectedPageId: Int?
    var window: Window = .campaign
    private(set) var numbers: Numbers?
    /// Nil when EN won't share them (FundraisingRollCall may be off, e.g. in the UK and EU).
    private(set) var recentGifts: [ENRecentGift]?
    /// Oldest first, today last. Nil until every day has loaded, or when one failed.
    private(set) var dailyTotals: [GivingStats.DailyTotal]?
    /// Nil while loading, when the page has no goal, or when EN couldn't be asked.
    private(set) var goalFigures: GoalFigures?
    private(set) var isLoading = false
    /// Why the last load failed, in plain words. Nil when it worked.
    private(set) var errorMessage: String?

    private struct Key: Hashable {
        let pageId: Int
        let window: Window
    }

    private var numbersCache: [Key: (numbers: Numbers, fetchedAt: Date)] = [:]
    /// By campaign ID. Personal data: kept in memory only, never saved.
    private var giftsCache: [Int: (gifts: [ENRecentGift]?, fetchedAt: Date)] = [:]
    /// What each page raised by day (one call per day: EN gives totals, not a breakdown).
    /// Days before yesterday are done, so they're fetched once; today and yesterday are
    /// fetched again once stale.
    private var dailyCache: [Int: [Date: Decimal]] = [:]
    private var dailyFetchedAt: [Int: Date] = [:]
    private let client: ENClient

    init(credentials: ENCredentials) {
        client = ENClient(credentials: credentials)
    }

    var selectedPage: Page? {
        pages.first { $0.pageId == selectedPageId } ?? pages.first
    }

    /// What to load; the view reloads whenever it changes.
    var loadKey: String { "\(selectedPage?.pageId ?? 0)-\(window.rawValue)-\(selectedPage?.hasGoal ?? false)" }

    /// "Raised so far", "Raised in the last 30 days".
    var raisedTitle: String {
        window.days.map { "Raised in the last \($0) days" } ?? "Raised so far"
    }

    func update(pages newPages: [Page]) {
        pages = newPages
        if selectedPageId == nil || !newPages.contains(where: { $0.pageId == selectedPageId }) {
            selectedPageId = newPages.first?.pageId
        }
    }

    // MARK: Loading

    func load(force: Bool = false, in context: ModelContext) async {
        guard let page = selectedPage else {
            numbers = nil
            recentGifts = nil
            dailyTotals = nil
            goalFigures = nil
            return
        }
        let key = Key(pageId: page.pageId, window: window)
        let now = Date.now
        restoreSaved(key, in: context)
        goalFigures = page.hasGoal ? cachedGoalFigures(pageId: page.pageId, in: context) : nil
        let cached = numbersCache[key]
        let needsNumbers = force || cached.map { now.timeIntervalSince($0.fetchedAt) >= Self.staleAfter } ?? true

        // Show what's already known while anything new loads.
        numbers = cached?.numbers
        recentGifts = giftsCache[page.campaignId]?.gifts
        dailyTotals = cachedDailyTotals(pageId: page.pageId, now: now)
        isLoading = needsNumbers

        async let giftsDone: Void = refreshGiftsIfStale(campaignId: page.campaignId, force: force, now: now)
        if needsNumbers {
            let result = await fetchNumbers(pageId: page.pageId, window: key.window, now: now)
            if case .success(let fresh) = result {
                numbersCache[key] = (fresh, now)
                SavedNumbers.save(fresh, as: Self.numbersKey(key), at: now, in: context)
            }
            if isStillShowing(key) {
                switch result {
                case .success(let fresh):
                    numbers = fresh
                    errorMessage = nil
                case .failure(let error):
                    errorMessage = error.userMessage
                }
            }
        }
        if isStillShowing(key) { isLoading = false }
        if page.hasGoal {
            await refreshGoalNumbers(pageId: page.pageId, force: force, now: now, in: context)
            if isStillShowing(key) {
                goalFigures = cachedGoalFigures(pageId: page.pageId, in: context)
            }
        }
        // After the headline numbers, so its 14 calls don't hold them up.
        await refreshDailyIfStale(pageId: page.pageId, force: force, now: now)
        if let daily = dailyCache[page.pageId], let fetchedAt = dailyFetchedAt[page.pageId] {
            SavedNumbers.save(daily, as: Self.dailyKey(page.pageId), at: fetchedAt, in: context)
        }
        await giftsDone
        guard isStillShowing(key) else { return }
        isLoading = false
        recentGifts = giftsCache[page.campaignId]?.gifts
        dailyTotals = cachedDailyTotals(pageId: page.pageId, now: now)
    }

    // MARK: Saved on the device

    private static func numbersKey(_ key: Key) -> String { "giving.numbers.\(key.pageId).\(key.window.rawValue)" }
    private static func dailyKey(_ pageId: Int) -> String { "giving.daily.\(pageId)" }

    /// The first time a page or window is shown, starts from what was saved on the device.
    /// Donors are never saved (personal data), so that card waits for the network.
    private func restoreSaved(_ key: Key, in context: ModelContext) {
        if numbersCache[key] == nil,
           let saved = SavedNumbers.load(Numbers.self, key: Self.numbersKey(key), in: context) {
            numbersCache[key] = (saved.value, saved.savedAt)
        }
        if dailyCache[key.pageId] == nil,
           let saved = SavedNumbers.load([Date: Decimal].self, key: Self.dailyKey(key.pageId), in: context) {
            dailyCache[key.pageId] = saved.value
            dailyFetchedAt[key.pageId] = saved.savedAt
        }
    }

    // MARK: Goal

    /// The goal card needs the campaign total and the last 7 days, whichever span is picked.
    private static let goalWindows: [Window] = [.campaign, .lastSevenDays]

    private func refreshGoalNumbers(pageId: Int, force: Bool, now: Date, in context: ModelContext) async {
        for window in Self.goalWindows {
            let key = Key(pageId: pageId, window: window)
            restoreSaved(key, in: context)
            if !force, let cached = numbersCache[key], now.timeIntervalSince(cached.fetchedAt) < Self.staleAfter { continue }
            // A failure keeps what was there; the card then shows the older figures.
            if case .success(let fresh) = await fetchNumbers(pageId: pageId, window: window, now: now) {
                numbersCache[key] = (fresh, now)
                SavedNumbers.save(fresh, as: Self.numbersKey(key), at: now, in: context)
            }
        }
    }

    private func cachedGoalFigures(pageId: Int, in context: ModelContext) -> GoalFigures? {
        for window in Self.goalWindows {
            restoreSaved(Key(pageId: pageId, window: window), in: context)
        }
        guard let campaign = numbersCache[Key(pageId: pageId, window: .campaign)],
              let recent = numbersCache[Key(pageId: pageId, window: .lastSevenDays)]
        else { return nil }
        return GoalFigures(raised: campaign.numbers.current.raised, recentRaised: recent.numbers.current.raised)
    }

    /// False when the user picked another page or window meanwhile (that load takes over).
    private func isStillShowing(_ key: Key) -> Bool {
        !Task.isCancelled && key == Key(pageId: selectedPage?.pageId ?? 0, window: window)
    }

    private func fetchNumbers(pageId: Int, window: Window, now: Date) async -> Result<Numbers, ENError> {
        let currency = AccountSettings.reportingCurrency
        do {
            guard let days = window.days else {
                let today = Calendar.current.startOfDay(for: now)
                let total = try await client.pageGiving(pageId: pageId, from: Self.campaignStart, through: today)
                return .success(Numbers(current: GivingStats.Summary(total, currency: currency), previous: nil))
            }
            // Complete days only, ending yesterday, so both windows compare fairly.
            let period = DayRange.last(days, daysBefore: now)
            let before = period.previous()
            async let current = client.pageGiving(pageId: pageId, from: period.firstDay, through: period.lastDay)
            async let previous = client.pageGiving(pageId: pageId, from: before.firstDay, through: before.lastDay)
            return .success(Numbers(current: GivingStats.Summary(try await current, currency: currency),
                                    previous: GivingStats.Summary(try await previous, currency: currency)))
        } catch let error as ENError {
            return .failure(error)
        } catch {
            return .failure(.network)
        }
    }

    private func refreshDailyIfStale(pageId: Int, force: Bool, now: Date) async {
        let calendar = Calendar.current
        let days = DayRange.last(Self.chartDays, throughToday: now, calendar: calendar).days(calendar: calendar)
        let yesterday = days.dropLast().last ?? now
        let known = dailyCache[pageId] ?? [:]
        let recentIsStale = force || dailyFetchedAt[pageId].map { now.timeIntervalSince($0) >= Self.staleAfter } ?? true
        // Days that weren't over (or only just over) when last fetched get fetched again.
        // That can reach further back than yesterday when the totals were saved days ago.
        let recheckFrom = dailyFetchedAt[pageId].map { fetchedAt in
            min(yesterday, calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: fetchedAt)) ?? yesterday)
        } ?? yesterday
        let toFetch = days.filter { known[$0] == nil || ($0 >= recheckFrom && recentIsStale) }
        guard !toFetch.isEmpty else { return }

        let currency = AccountSettings.reportingCurrency
        let client = client
        let fetched = await withTaskGroup(of: (Date, Decimal?).self) { group in
            for day in toFetch {
                group.addTask {
                    // No row (nil) means no gifts that day, so $0. An error leaves the day
                    // out, to retry next time. (Not `try?`: it would mix the two up.)
                    do {
                        let giving = try await client.pageGiving(pageId: pageId, from: day, through: day)
                        return (day, GivingStats.Summary(giving, currency: currency).raised)
                    } catch {
                        return (day, nil)
                    }
                }
            }
            var results: [Date: Decimal?] = [:]
            for await (day, raised) in group {
                results.updateValue(raised, forKey: day)
            }
            return results
        }
        // Read the cache again: another load may have filled it while this one waited.
        var updated = dailyCache[pageId] ?? [:]
        for (day, raised) in fetched {
            // A failed refetch keeps what was there.
            if let raised { updated[day] = raised }
        }
        // Forget days that have scrolled out of the chart.
        dailyCache[pageId] = updated.filter { $0.key >= (days.first ?? now) }
        if fetched.values.allSatisfy({ $0 != nil }) {
            dailyFetchedAt[pageId] = now
        }
    }

    private func cachedDailyTotals(pageId: Int, now: Date) -> [GivingStats.DailyTotal]? {
        guard let known = dailyCache[pageId] else { return nil }
        var totals: [GivingStats.DailyTotal] = []
        for day in DayRange.last(Self.chartDays, throughToday: now).days() {
            guard let raised = known[day] else { return nil }
            totals.append(GivingStats.DailyTotal(day: day, raised: raised))
        }
        return totals
    }

    private func refreshGiftsIfStale(campaignId: Int, force: Bool, now: Date) async {
        if !force, let cached = giftsCache[campaignId], now.timeIntervalSince(cached.fetchedAt) < Self.staleAfter { return }
        // An error means the service is off or failed: hide the card.
        let gifts = try? await client.recentGifts(campaignId: campaignId)
        giftsCache[campaignId] = (gifts, now)
    }
}
