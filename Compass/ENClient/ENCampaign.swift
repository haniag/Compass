//
//  ENCampaign.swift
//  Compass
//
//  One row of EaCampaignInfo. The API gives name and status only — no page type.
//

import Foundation

nonisolated struct ENCampaign: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    /// Raw EN status, e.g. "Live", "New", "Closed", "Deleted", "Blocked".
    let status: String

    init(id: Int, name: String, status: String) {
        self.id = id
        self.name = name
        self.status = status
    }

    init?(row: ENRow) {
        guard let id = row.int("campaignId") else { return nil }
        self.init(
            id: id,
            name: row.string("campaignName") ?? row.string("campaignExportName") ?? "Campaign \(id)",
            status: row.string("campaignStatus") ?? ""
        )
    }

    var isLive: Bool { status.caseInsensitiveCompare("Live") == .orderedSame }

    /// Deleted and blocked campaigns are returned by the API but aren't worth following.
    var isRemoved: Bool {
        let lowered = status.lowercased()
        return lowered.contains("delete") || lowered.contains("block")
    }

    /// Plain-language status for the picker.
    var statusLabel: String {
        switch status.lowercased() {
        case "live": "Live"
        case "new": "Not live yet"
        case "closed": "Closed"
        case "": "Page"
        default: status
        }
    }
}
