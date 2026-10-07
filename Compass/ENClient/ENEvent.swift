//
//  ENEvent.swift
//  Compass
//
//  One row of EventDetails (upcoming events only).
//

import Foundation

nonisolated struct ENEvent: Identifiable, Hashable, Sendable {
    let campaignId: Int
    let pageId: Int?
    let name: String
    /// UTC midnight of the start day.
    let startDate: Date?
    let city: String?
    let isOnline: Bool

    var id: Int { campaignId }

    init(campaignId: Int, pageId: Int?, name: String, startDate: Date?, city: String?, isOnline: Bool) {
        self.campaignId = campaignId
        self.pageId = pageId
        self.name = name
        self.startDate = startDate
        self.city = city
        self.isOnline = isOnline
    }

    init?(row: ENRow) {
        guard let campaignId = row.int("CAMPAIGN_ID") else { return nil }
        self.init(
            campaignId: campaignId,
            pageId: row.int("CAMPAIGN_PAGE_ID"),
            name: row.string("PAGE_TITLE") ?? row.string("PAGE_NAME") ?? "Event \(campaignId)",
            startDate: row.string("EVENT_START_DATE").flatMap(ENDateFormat.iso),
            city: row.string("CITY"),
            isOnline: row.string("ONLINE_EVENT")?.uppercased() == "Y"
        )
    }

    /// "Oct 4 · Portland", "Oct 4 · Online".
    var summary: String {
        var parts: [String] = []
        if let startDate {
            parts.append(startDate.formatted(Date.FormatStyle(timeZone: .gmt).month(.abbreviated).day()))
        }
        if isOnline {
            parts.append("Online")
        } else if let city {
            parts.append(city)
        }
        return parts.joined(separator: " · ")
    }
}
