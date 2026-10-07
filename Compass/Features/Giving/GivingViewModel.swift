//
//  GivingViewModel.swift
//  Compass
//
//  Giving tab: one donation page's gifts over the last 7 or 30 days (against the
//  days before) or the whole campaign, and its donors from the last 7 days.
//

import Foundation
import Observation

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

        var id: Int { pageId }
    }

    struct Numbers: Hashable {
        let current: GivingStats.Summary
        /// The same number of days just before. Nil for the whole campaign.
        let previous: GivingStats.Summary?
    }

    /// Don't re-fetch on every visit; pull to refresh is always available.
    private static let staleAfter: TimeInterval = 30 * 60
    /// "Since the campaign began": EN needs a start date, and accepts one this early.
    private static let campaignStart = DateComponents(calendar: .current, year: 2000, month: 1, day: 1).date ?? .distantPast

    private(set) var pages: [Page] = []
    var selectedPageId: Int?
    var window: Window = .campaign
    private(set) var numbers: Numbers?
    /// Nil when EN won't share them (FundraisingRollCall may be off, e.g. in the UK and EU).
    private(set) var recentGifts: [ENRecentGift]?
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
    private let client: ENClient

    init(credentials: ENCredentials) {
        client = ENClient(credentials: credentials)
    }

    var selectedPage: Page? {
        pages.first { $0.pageId == selectedPageId } ?? pages.first
    }

    /// What to load; the view reloads whenever it changes.
    var loadKey: String { "\(selectedPage?.pageId ?? 0)-\(window.rawValue)" }

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

    func load(force: Bool = false) async {
        guard let page = selectedPage else {
            numbers = nil
            recentGifts = nil
            return
        }
        let key = Key(pageId: page.pageId, window: window)
        let now = Date.now
        let cached = numbersCache[key]
        let needsNumbers = force || cached.map { now.timeIntervalSince($0.fetchedAt) >= Self.staleAfter } ?? true

        // Show what's already known while anything new loads.
        numbers = cached?.numbers
        recentGifts = giftsCache[page.campaignId]?.gifts
        isLoading = needsNumbers

        async let giftsDone: Void = refreshGiftsIfStale(campaignId: page.campaignId, force: force, now: now)
        if needsNumbers {
            let result = await fetchNumbers(pageId: page.pageId, window: key.window, now: now)
            if case .success(let fresh) = result {
                numbersCache[key] = (fresh, now)
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
        await giftsDone
        guard isStillShowing(key) else { return }
        isLoading = false
        recentGifts = giftsCache[page.campaignId]?.gifts
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

    private func refreshGiftsIfStale(campaignId: Int, force: Bool, now: Date) async {
        if !force, let cached = giftsCache[campaignId], now.timeIntervalSince(cached.fetchedAt) < Self.staleAfter { return }
        // An error means the service is off or failed: hide the card.
        let gifts = try? await client.recentGifts(campaignId: campaignId)
        giftsCache[campaignId] = (gifts, now)
    }
}
