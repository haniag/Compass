//
//  ENClient.swift
//  Compass
//
//  Talks to the Engaging Networks Public Data Service. Runs off the main thread (actor).
//

import Foundation

actor ENClient {
    private let credentials: ENCredentials
    private let session: URLSession

    /// EN's rate limits are undocumented, so never run more than this many requests at once.
    private let maxConcurrentRequests = 4
    private var activeRequests = 0
    private var waitingRequests: [CheckedContinuation<Void, Never>] = []

    init(credentials: ENCredentials, session: URLSession = .shared) {
        self.credentials = credentials
        self.session = session
    }

    // MARK: Services

    /// `EaSupporterCount`: total supporter records in the account. Also used as the
    /// "does this token work?" check during onboarding.
    func supporterCount() async throws(ENError) -> Int {
        let rows = try await fetch(service: "EaSupporterCount")
        guard let count = rows.first?.int("supporterCount") else { throw .unexpectedResponse }
        return count
    }

    /// `EaCampaignInfo`. With no IDs, EN returns every campaign in the account
    /// (including deleted and blocked ones); with IDs, just those.
    func campaigns(ids: [Int] = []) async throws(ENError) -> [ENCampaign] {
        let parameters = ids.isEmpty ? [:] : ["campaignId": ids.map(String.init).joined(separator: ",")]
        return try await fetch(service: "EaCampaignInfo", parameters: parameters)
            .compactMap(ENCampaign.init(row:))
    }

    /// `EventDetails`: events that finish in the future, public and private.
    func upcomingEvents() async throws(ENError) -> [ENEvent] {
        try await fetch(service: "EventDetails", parameters: ["publicOnly": "N"])
            .compactMap(ENEvent.init(row:))
    }

    /// `AccountReports` › newjoins: supporters who joined between two days (inclusive).
    func newJoins(from firstDay: Date, through lastDay: Date) async throws(ENError) -> Int {
        let rows = try await accountReport(.newJoins, from: firstDay, through: lastDay)
        guard let total = rows.typeCounts["total"] else {
            if rows.isEmpty { return 0 }
            throw .unexpectedResponse
        }
        return NSDecimalNumber(decimal: total).intValue
    }

    /// `AccountReports` › netdonoramounts: gifts per currency between two days (inclusive).
    func donationAmounts(from firstDay: Date, through lastDay: Date) async throws(ENError) -> [ENDonationAmount] {
        try await accountReport(.donorAmounts, from: firstDay, through: lastDay)
            .compactMap(ENDonationAmount.init(row:))
    }

    /// `AccountReports` › broadcaststats: emails sent and open rate between two days (inclusive).
    func broadcastStats(from firstDay: Date, through lastDay: Date) async throws(ENError) -> ENBroadcastStats {
        let counts = try await accountReport(.broadcastStats, from: firstDay, through: lastDay).typeCounts
        let sent = counts["number of emails"].map { NSDecimalNumber(decimal: $0).intValue } ?? 0
        return ENBroadcastStats(emailsSent: sent, openRate: sent > 0 ? counts["percentage open rate"] : nil)
    }

    /// `EaBroadcastInfo`: email sends from `firstDay` on, newest first. EN returns at most
    /// 100 rows per call, so this asks page by page (rows 1–100, 101–200…) until it reaches
    /// older sends, up to `maxPages` calls.
    func broadcasts(since firstDay: Date, maxPages: Int = 5) async throws(ENError) -> [ENBroadcast] {
        let pageSize = 100
        var sends: [ENBroadcast] = []
        for page in 0..<maxPages {
            let firstRow = page * pageSize + 1
            let rows: [ENRow]
            do {
                rows = try await fetch(service: "EaBroadcastInfo", parameters: [
                    "startRow": String(firstRow),
                    "endRow": String(firstRow + pageSize - 1),
                ])
            } catch {
                // Keep what earlier pages found; only fail if there's nothing at all.
                if page == 0 { throw error }
                break
            }
            let pageSends = rows.compactMap { ENBroadcast(row: $0) }
            sends += pageSends.filter { $0.sentOn >= firstDay }
            let reachedOlderSends = (pageSends.last?.sentOn ?? .distantPast) < firstDay
            if rows.count < pageSize || reachedOlderSends { break }
        }
        return sends
    }

    private func accountReport(_ type: ENAccountReportType, from firstDay: Date, through lastDay: Date) async throws(ENError) -> [ENRow] {
        try await fetch(service: "AccountReports", parameters: [
            "resultType": type.rawValue,
            "startDate": ENDateFormat.ddMMyyyyString(from: firstDay),
            "endDate": ENDateFormat.ddMMyyyyString(from: lastDay),
        ])
    }

    /// `FundraisingSummaryByPage`: gifts through one page between two days (inclusive).
    /// Nil when there were none: EN sends no row then.
    func pageGiving(pageId: Int, from firstDay: Date, through lastDay: Date) async throws(ENError) -> ENPageGiving? {
        try await fetch(service: "FundraisingSummaryByPage", parameters: [
            "pageid": String(pageId),
            "startDate": ENDateFormat.isoString(from: firstDay, calendar: .current),
            "endDate": ENDateFormat.isoString(from: lastDay, calendar: .current),
        ]).compactMap(ENPageGiving.init(row:)).first
    }

    /// `FundraisingRollCall`: gifts to a campaign in the last 7 days. Names and cities
    /// are personal data: show them, never store them.
    func recentGifts(campaignId: Int) async throws(ENError) -> [ENRecentGift] {
        try await fetch(service: "FundraisingRollCall", parameters: ["campaignId": String(campaignId)])
            .compactMap(ENRecentGift.init(row:))
    }

    /// Reads a page's name, campaign and type from the live page (`/page/{pageId}`, no token).
    /// Always asks this account's own EN host, whatever site the user's link pointed to.
    func pageDetails(pageId: Int) async throws(ENError) -> ENPageDetails {
        #if DEBUG
        if credentials.isDemo {
            try? await Task.sleep(for: .milliseconds(400))
            guard let details = ENDemoData.pageDetails(pageId: pageId) else { throw .pageUnavailable }
            return details
        }
        #endif

        await acquireSlot()
        defer { releaseSlot() }

        var components = URLComponents()
        components.scheme = "https"
        components.host = credentials.region.host
        components.path = "/page/\(pageId)"
        let data: Data
        let response: URLResponse
        do {
            // Host is fixed and the path is a number, so this can't fail.
            (data, response) = try await session.data(from: components.url!)
        } catch {
            throw .network
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { throw .pageUnavailable }
            if !(200..<300).contains(http.statusCode) { throw .httpStatus(http.statusCode) }
        }
        guard let details = ENPageDetails(html: String(decoding: data, as: UTF8.self)) else { throw .pageUnavailable }
        return details
    }

    // MARK: Plumbing

    private func fetch(service: String, parameters: [String: String] = [:]) async throws(ENError) -> [ENRow] {
        let data: Data
        #if DEBUG
        if credentials.isDemo {
            try? await Task.sleep(for: .milliseconds(400))
            return try ENResponse.rows(from: ENDemoData.json(service: service, parameters: parameters))
        }
        #endif

        await acquireSlot()
        defer { releaseSlot() }

        let response: URLResponse
        do {
            (data, response) = try await session.data(from: makeURL(service: service, parameters: parameters))
        } catch {
            throw .network
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw .httpStatus(http.statusCode)
        }
        return try ENResponse.rows(from: data)
    }

    private func makeURL(service: String, parameters: [String: String]) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = credentials.region.host
        components.path = "/ea-dataservice/data.service"
        components.queryItems = [
            URLQueryItem(name: "service", value: service),
            URLQueryItem(name: "token", value: credentials.token),
            URLQueryItem(name: "contentType", value: "json"),
        ] + parameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        // Host and path are fixed and valid, so this can't fail.
        return components.url!
    }

    // MARK: Concurrency cap

    private func acquireSlot() async {
        if activeRequests < maxConcurrentRequests {
            activeRequests += 1
            return
        }
        // Wait; releaseSlot() hands its slot straight to us.
        await withCheckedContinuation { waitingRequests.append($0) }
    }

    private func releaseSlot() {
        if waitingRequests.isEmpty {
            activeRequests -= 1
        } else {
            waitingRequests.removeFirst().resume()
        }
    }
}
