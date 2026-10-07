//
//  FollowedPage.swift
//  Compass
//
//  A page or event the user chose to track during onboarding (or later).
//

import Foundation
import SwiftData

@Model
final class FollowedPage {
    enum Kind: String, Codable {
        case page
        case event
    }

    @Attribute(.unique) var campaignId: Int
    var name: String
    var kindRaw: String
    var addedAt: Date
    /// The page's own ID, from its link. Giving needs it (FundraisingSummaryByPage
    /// takes page IDs, not campaign IDs). Nil for pages picked from the campaign list.
    var pageId: Int?
    /// EN's type for that page: "donation", "event"…
    var pageType: String?

    var kind: Kind {
        get { Kind(rawValue: kindRaw) ?? .page }
        set { kindRaw = newValue.rawValue }
    }

    init(campaignId: Int, name: String, kind: Kind, addedAt: Date = .now, pageId: Int? = nil, pageType: String? = nil) {
        self.campaignId = campaignId
        self.name = name
        self.kindRaw = kind.rawValue
        self.addedAt = addedAt
        self.pageId = pageId
        self.pageType = pageType
    }

    /// Follows a page found from its link. If its campaign is already followed,
    /// that entry gets the page ID instead of a second entry.
    @discardableResult
    static func follow(_ details: ENPageDetails, in context: ModelContext) -> FollowedPage {
        let campaignId = details.campaignId
        let existing = try? context.fetch(FetchDescriptor<FollowedPage>(predicate: #Predicate { $0.campaignId == campaignId })).first
        let page = existing ?? FollowedPage(campaignId: campaignId, name: details.name,
                                            kind: details.type == "event" ? .event : .page)
        page.pageId = details.pageId
        page.pageType = details.type
        if existing == nil {
            context.insert(page)
        }
        try? context.save()
        return page
    }
}
