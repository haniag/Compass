//
//  FollowedPageTests.swift
//  CompassTests
//
//  Following a page from its link.
//

import Foundation
import SwiftData
import Testing
@testable import Compass

@MainActor
struct FollowedPageTests {
    private let context: ModelContext

    init() throws {
        let container = try ModelContainer(for: FollowedPage.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
    }

    private var all: [FollowedPage] { (try? context.fetch(FetchDescriptor<FollowedPage>())) ?? [] }

    @Test func followsANewPageWithItsPageID() {
        FollowedPage.follow(ENPageDetails(pageId: 71101, campaignId: 5101, name: "Fall Appeal 2026", type: "donation"), in: context)
        #expect(all.count == 1)
        #expect(all.first?.pageId == 71101)
        #expect(all.first?.pageType == "donation")
        #expect(all.first?.kind == .page)
    }

    @Test func addsThePageIDToACampaignAlreadyFollowed() {
        context.insert(FollowedPage(campaignId: 5101, name: "Fall Appeal (from the list)", kind: .page))
        FollowedPage.follow(ENPageDetails(pageId: 71101, campaignId: 5101, name: "Fall Appeal 2026", type: "donation"), in: context)
        #expect(all.count == 1)
        #expect(all.first?.pageId == 71101)
        #expect(all.first?.name == "Fall Appeal (from the list)")  // keeps the name it had
    }
}
