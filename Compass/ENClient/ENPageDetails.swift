//
//  ENPageDetails.swift
//  Compass
//
//  What a live EN page says about itself. Every published page carries
//  `var pageJson = {"campaignPageId":…,"campaignId":…,"pageName":…,"pageType":…};`
//  (verified on the test account, Oct 2026). Inactive pages don't.
//

import Foundation

nonisolated struct ENPageDetails: Hashable, Sendable {
    let pageId: Int
    let campaignId: Int
    let name: String
    /// EN's page type: "donation", "event", "advocacypetition", "emailtotarget"…
    let type: String

    init(pageId: Int, campaignId: Int, name: String, type: String) {
        self.pageId = pageId
        self.campaignId = campaignId
        self.name = name
        self.type = type
    }

    /// Reads the `pageJson` block out of a page's HTML. Nil when it isn't there.
    init?(html: String) {
        guard let start = html.range(of: "var pageJson =")?.upperBound,
              let end = html.range(of: "</script>", range: start..<html.endIndex)?.lowerBound
        else { return nil }
        var json = html[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasSuffix(";") { json.removeLast() }
        guard let page = try? JSONDecoder().decode(PageJSON.self, from: Data(json.utf8)) else { return nil }
        self.init(
            pageId: page.campaignPageId,
            campaignId: page.campaignId,
            name: page.pageName?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? "Page \(page.campaignPageId)",
            type: page.pageType?.lowercased() ?? ""
        )
    }

    /// Donation and event pages take payments, so they have giving to show.
    var takesGifts: Bool { type == "donation" || type == "event" }

    /// "petition", "survey"… for messages.
    var typeLabel: String {
        switch type {
        case "donation": "donation"
        case "event": "event"
        case "advocacypetition": "petition"
        case "emailtotarget", "tweettotarget", "calltotarget": "action"
        case "survey", "datacapture": "survey"
        default: type.isEmpty ? "non-donation" : type
        }
    }

    private struct PageJSON: Decodable {
        let campaignPageId: Int
        let campaignId: Int
        let pageName: String?
        let pageType: String?

        private enum CodingKeys: String, CodingKey { case campaignPageId, campaignId, pageName, pageType }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            campaignPageId = try Self.flexibleInt(container, .campaignPageId)
            campaignId = try Self.flexibleInt(container, .campaignId)
            pageName = try? container.decodeIfPresent(String.self, forKey: .pageName)
            pageType = try? container.decodeIfPresent(String.self, forKey: .pageType)
        }

        /// The IDs are numbers today; accept "17697" too, in case that changes.
        private static func flexibleInt(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> Int {
            if let number = try? container.decode(Int.self, forKey: key) { return number }
            if let text = try? container.decode(String.self, forKey: key), let number = Int(text) { return number }
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Not an ID")
        }
    }
}

/// Finding the page ID in what the user pasted.
nonisolated enum ENPageLink {
    /// "https://act.example.org/page/17697/donate/1" → 17697. A bare "17697" works too.
    static func pageId(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Int(trimmed) { return number > 0 ? number : nil }
        guard let match = trimmed.range(of: #"/page/\d+"#, options: .regularExpression) else { return nil }
        return Int(trimmed[match].dropFirst("/page/".count))
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? { isEmpty ? nil : self }
}
