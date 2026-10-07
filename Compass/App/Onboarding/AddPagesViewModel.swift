//
//  AddPagesViewModel.swift
//  Compass
//
//  Onboarding step 2: choose which pages and events Compass tracks. Donation pages
//  added by link (for Giving) are saved straight away and managed in their own card.
//

import Foundation
import Observation
import SwiftData

@Observable
final class AddPagesViewModel {
    enum LoadState<Value> {
        case loading
        case loaded(Value)
        /// The service failed or is turned off: hide or fall back, don't break the screen.
        case unavailable
    }

    enum ManualLookup: Equatable {
        case idle
        case looking
        case failed(message: String)
    }

    private(set) var campaigns: LoadState<[ENCampaign]> = .loading
    private(set) var events: LoadState<[ENEvent]> = .loading
    /// Campaigns added by ID when the full list isn't available.
    private(set) var manualCampaigns: [ENCampaign] = []
    private(set) var selectedIDs: Set<Int> = []

    var searchText = ""
    var manualIDText = ""
    private(set) var manualLookup: ManualLookup = .idle

    private let client: ENClient
    private var followedNames: [Int: (name: String, kind: FollowedPage.Kind)] = [:]
    private var preselectEvents = true
    private var hasLoaded = false

    init(credentials: ENCredentials) {
        client = ENClient(credentials: credentials)
    }

    // MARK: Loading

    /// Loads pages and events in parallel. `alreadyFollowed` restores an earlier choice.
    func load(alreadyFollowed: [FollowedPage]) async {
        guard !hasLoaded else { return }
        hasLoaded = true

        if !alreadyFollowed.isEmpty {
            preselectEvents = false
            // Pages added by link have their own card, so they aren't chips here too.
            let picked = alreadyFollowed.filter { $0.pageId == nil }
            selectedIDs = Set(picked.map(\.campaignId))
            for page in picked {
                followedNames[page.campaignId] = (page.name, page.kind)
            }
        }

        async let pagesDone: Void = loadCampaigns()
        async let eventsDone: Void = loadEvents()
        _ = await (pagesDone, eventsDone)
    }

    private func loadCampaigns() async {
        do {
            let all = try await client.campaigns()
            campaigns = all.isEmpty ? .unavailable : .loaded(all.filter { !$0.isRemoved })
        } catch {
            campaigns = .unavailable
        }
    }

    private func loadEvents() async {
        do {
            let loaded = try await client.upcomingEvents()
            // An event can have several pages; keep one row per campaign.
            var seen = Set<Int>()
            let unique = loaded
                .filter { seen.insert($0.campaignId).inserted }
                .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
            events = .loaded(unique)
            if preselectEvents {
                selectedIDs.formUnion(unique.map(\.campaignId))
            }
        } catch {
            events = .unavailable
        }
    }

    // MARK: Derived lists

    var eventList: [ENEvent] {
        if case .loaded(let list) = events { list } else { [] }
    }

    private var eventIDs: Set<Int> { Set(eventList.map(\.campaignId)) }

    /// Everything the page picker can offer: live first, then by name.
    /// Events are left out because they have their own card.
    var pageOptions: [ENCampaign] {
        let loaded: [ENCampaign] = if case .loaded(let list) = campaigns { list } else { [] }
        let eventIDs = eventIDs
        return (loaded + manualCampaigns)
            .filter { !eventIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.isLive != rhs.isLive { return lhs.isLive }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    var filteredPageOptions: [ENCampaign] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return pageOptions }
        return pageOptions.filter {
            $0.name.localizedStandardContains(query) || $0.statusLabel.localizedStandardContains(query)
        }
    }

    /// Selected pages (not events), for the chips under the dropdown.
    var selectedPages: [(id: Int, name: String)] {
        let optionNames = Dictionary(pageOptions.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let eventIDs = eventIDs
        return selectedIDs
            .filter { !eventIDs.contains($0) && followedNames[$0]?.kind != .event }
            .compactMap { id in
                guard let name = optionNames[id] ?? followedNames[id]?.name else { return nil }
                return (id, name)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var pickerSummary: String {
        switch selectedPages.count {
        case 0: "Choose pages"
        case 1: "1 page selected"
        case let count: "\(count) pages selected"
        }
    }

    // MARK: Selection

    func isSelected(_ id: Int) -> Bool { selectedIDs.contains(id) }

    func toggle(_ id: Int) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    // MARK: Fallback: add by campaign ID

    func addManualCampaign() async {
        guard let id = Int(manualIDText.trimmingCharacters(in: .whitespaces)) else {
            manualLookup = .failed(message: "A campaign ID is a number, like 12346.")
            return
        }
        manualLookup = .looking
        do {
            guard let campaign = try await client.campaigns(ids: [id]).first(where: { $0.id == id }) else {
                manualLookup = .failed(message: "No campaign with ID \(id) was found in your account.")
                return
            }
            if !manualCampaigns.contains(where: { $0.id == id }) {
                manualCampaigns.append(campaign)
            }
            selectedIDs.insert(id)
            manualIDText = ""
            manualLookup = .idle
        } catch {
            manualLookup = .failed(message: error.userMessage)
        }
    }

    // MARK: Saving

    /// Stops following a page added by link.
    func stopFollowing(_ page: FollowedPage, in context: ModelContext) {
        context.delete(page)
        try? context.save()
    }

    /// Replaces the followed pages with the current selection. Pages added by link
    /// are kept: they're removed from their own card.
    func save(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<FollowedPage>())) ?? []
        for page in existing where page.pageId == nil && !selectedIDs.contains(page.campaignId) {
            context.delete(page)
        }

        let existingIDs = Set(existing.map(\.campaignId))
        for event in eventList where selectedIDs.contains(event.campaignId) && !existingIDs.contains(event.campaignId) {
            context.insert(FollowedPage(campaignId: event.campaignId, name: event.name, kind: .event))
        }
        for page in selectedPages where !existingIDs.contains(page.id) {
            context.insert(FollowedPage(campaignId: page.id, name: page.name, kind: .page))
        }
        try? context.save()
    }
}
