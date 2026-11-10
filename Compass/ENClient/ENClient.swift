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

    /// How long to wait before each new try after a failure that may pass by itself
    /// (no connection, a timeout, EN busy). Two waits means three tries in all.
    private let retryDelays: [Duration]
    /// Requests under way, by URL. Two screens asking for the same thing share one request.
    private var inFlight: [URL: Task<(Data, Int), any Error>] = [:]

    init(credentials: ENCredentials, session: URLSession = .shared,
         retryDelays: [Duration] = [.seconds(1), .seconds(3)]) {
        self.credentials = credentials
        self.session = session
        self.retryDelays = retryDelays
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

        var components = URLComponents()
        components.scheme = "https"
        components.host = credentials.region.host
        components.path = "/page/\(pageId)"
        // Host is fixed and the path is a number, so this can't fail.
        let (data, status) = try await download(components.url!)
        if status == 404 { throw .pageUnavailable }
        if !(200..<300).contains(status) { throw .httpStatus(status) }
        guard let details = ENPageDetails(html: String(decoding: data, as: UTF8.self)) else { throw .pageUnavailable }
        return details
    }

    // MARK: Plumbing

    private func fetch(service: String, parameters: [String: String] = [:]) async throws(ENError) -> [ENRow] {
        #if DEBUG
        if credentials.isDemo {
            try? await Task.sleep(for: .milliseconds(400))
            return try ENResponse.rows(from: ENDemoData.json(service: service, parameters: parameters))
        }
        #endif

        let (data, status) = try await download(makeURL(service: service, parameters: parameters))
        if !(200..<300).contains(status) { throw .httpStatus(status) }
        return try ENResponse.rows(from: data)
    }

    /// The body and HTTP status for `url`. If the same URL is already being fetched,
    /// waits for that request instead of sending a second one.
    private func download(_ url: URL) async throws(ENError) -> (Data, Int) {
        let request: Task<(Data, Int), any Error>
        if let running = inFlight[url] {
            request = running
        } else {
            request = Task { try await self.downloadWithRetries(url) }
            inFlight[url] = request
        }
        let result = await request.result
        // Only forget our own request: a newer one for this URL may have started meanwhile.
        if inFlight[url] == request {
            inFlight[url] = nil
        }
        do {
            return try result.get()
        } catch {
            throw (error as? ENError) ?? .network
        }
    }

    /// Tries again, after a wait, when the failure may pass by itself: no connection,
    /// a timeout, EN busy (HTTP 429) or broken (5xx). Anything else is returned as it is.
    private func downloadWithRetries(_ url: URL) async throws(ENError) -> (Data, Int) {
        var attempt = 0
        while true {
            let result = await downloadOnce(url)
            let worthRetrying = switch result {
            case .failure: true
            case .success((_, let status)): status == 429 || (500..<600).contains(status)
            }
            guard worthRetrying, attempt < retryDelays.count,
                  (try? await Task.sleep(for: retryDelays[attempt])) != nil
            else { return try result.get() }
            attempt += 1
        }
    }

    private func downloadOnce(_ url: URL) async -> Result<(Data, Int), ENError> {
        await acquireSlot()
        defer { releaseSlot() }
        do {
            let (data, response) = try await session.data(from: url)
            return .success((data, (response as? HTTPURLResponse)?.statusCode ?? 200))
        } catch {
            return .failure(.network)
        }
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
