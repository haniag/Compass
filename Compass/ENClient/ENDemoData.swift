//
//  ENDemoData.swift
//  Compass
//
//  DEBUG ONLY. Fake Engaging Networks answers for the demo token "1", so the app can be
//  tried without a real account. Same JSON shape as the real service, so the real
//  decoding code runs. All names and numbers are invented.
//

#if DEBUG
import Foundation

nonisolated enum ENDemoData {
    static let token = "1"

    static let supporterCount = 48_312
    /// Supporter count history for the Pulse trend line: 12 weekly values, oldest first
    /// (the last one is a week ago; today's value is `supporterCount`).
    static let weeklySupporterHistory = [45_860, 46_050, 46_230, 46_390, 46_600, 46_840,
                                         47_060, 47_250, 47_480, 47_700, 47_910, 48_098]

    static func json(service: String, parameters: [String: String]) -> Data {
        switch service {
        case "EaSupporterCount":
            return rows([["clientId": "1", "supporterCount": String(supporterCount)]])
        case "EaCampaignInfo":
            return campaigns(ids: parameters["campaignId"])
        case "EventDetails":
            return events()
        case "AccountReports":
            return accountReport(parameters)
        case "EaBroadcastInfo":
            return broadcasts(parameters)
        case "FundraisingSummaryByPage":
            return pageGiving(parameters)
        case "FundraisingRollCall":
            return recentGifts(campaignId: parameters["campaignId"])
        default:
            return Data(#"{"error":"Service not available in demo mode"}"#.utf8)
        }
    }

    // MARK: Live pages

    /// Demo page links: …/page/71101 (Fall Appeal), 71102 (Monthly giving), 71103 (a petition).
    static func pageDetails(pageId: Int) -> ENPageDetails? {
        switch pageId {
        case 71101: ENPageDetails(pageId: 71101, campaignId: 5101, name: "Fall Appeal 2026", type: "donation")
        case 71102: ENPageDetails(pageId: 71102, campaignId: 5102, name: "Monthly giving", type: "donation")
        case 71103: ENPageDetails(pageId: 71103, campaignId: 5103, name: "Clean Water petition", type: "advocacypetition")
        default: nil
        }
    }

    // MARK: Services

    private static let campaignRows: [[String: String]] = [
        ["campaignId": "5101", "campaignName": "Fall Appeal 2026", "campaignStatus": "Live"],
        ["campaignId": "5102", "campaignName": "Monthly giving", "campaignStatus": "Live"],
        ["campaignId": "5103", "campaignName": "Clean Water petition", "campaignStatus": "Live"],
        ["campaignId": "5104", "campaignName": "Letter to the Governor", "campaignStatus": "Live"],
        ["campaignId": "5105", "campaignName": "Volunteer interest survey", "campaignStatus": "Live"],
        ["campaignId": "5106", "campaignName": "Winter Appeal 2026", "campaignStatus": "New"],
        ["campaignId": "5107", "campaignName": "Spring Appeal 2026", "campaignStatus": "Closed"],
        ["campaignId": "5108", "campaignName": "Old test page", "campaignStatus": "Deleted"],
        // Event campaigns also appear here, as they do in EN.
        ["campaignId": "6201", "campaignName": "Community Harvest Dinner", "campaignStatus": "Live"],
        ["campaignId": "6202", "campaignName": "5K Run for Meals", "campaignStatus": "Live"],
    ]

    private static func campaigns(ids: String?) -> Data {
        guard let ids else { return rows(campaignRows) }
        let wanted = Set(ids.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        return rows(campaignRows.filter { wanted.contains($0["campaignId"] ?? "") })
    }

    private static func events() -> Data {
        let today = Date.now
        func day(_ offset: Int) -> String {
            ENDateFormat.isoString(from: today.addingTimeInterval(Double(offset) * 86_400))
        }
        return rows([
            ["ID": "1", "CAMPAIGN_ID": "6201", "CAMPAIGN_PAGE_ID": "71201", "PAGE_NAME": "Harvest Dinner 2026",
             "PAGE_TITLE": "Community Harvest Dinner", "EVENT_START_DATE": day(10), "CITY": "Portland", "ONLINE_EVENT": "N"],
            ["ID": "2", "CAMPAIGN_ID": "6202", "CAMPAIGN_PAGE_ID": "71202", "PAGE_NAME": "5K 2026",
             "PAGE_TITLE": "5K Run for Meals", "EVENT_START_DATE": day(24), "CITY": "Portland", "ONLINE_EVENT": "N"],
            ["ID": "3", "CAMPAIGN_ID": "6203", "CAMPAIGN_PAGE_ID": "71203", "PAGE_NAME": "GT phone bank",
             "PAGE_TITLE": "Giving Tuesday phone bank", "EVENT_START_DATE": day(68), "CITY": "", "ONLINE_EVENT": "Y"],
        ])
    }

    /// The window ending yesterday gets "this week" numbers; any other window gets "the week before".
    private static func accountReport(_ parameters: [String: String]) -> Data {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        let isCurrentWeek = parameters["endDate"] == ENDateFormat.ddMMyyyyString(from: yesterday)

        switch parameters["resultType"] {
        case "newjoins":
            return typeCounts(["total": isCurrentWeek ? "386" : "342", "import": "0",
                               "netdonor": isCurrentWeek ? "121" : "110", "e-activist": isCurrentWeek ? "265" : "232"])
        case "netdonoramounts":
            return rows([isCurrentWeek
                         ? ["Currency": "USD", "Total": "23480.00", "Average": "57.27"]
                         : ["Currency": "USD", "Total": "21740.00", "Average": "59.56"]])
        case "netdonortransactions":
            return typeCounts(["failed donations": "3.0", "successful donations": isCurrentWeek ? "410.0" : "365.0"])
        case "broadcaststats":
            return typeCounts(["number of emails": isCurrentWeek ? "41200.0" : "39850.0",
                               "number of bounces (soft)": "120.0", "number of bounces (hard)": "35.0",
                               "percentage completion": "2.10", "percentage open rate": isCurrentWeek ? "38.2" : "39.6",
                               "percentage click through": "3.4", "total broadcasts": "3.0"])
        default:
            return typeCounts(["total activity": "870"])
        }
    }

    /// Email sends, newest first: days ago, name, emails sent, then open, click and
    /// unsubscribe rates in percent. The newest three lose more supporters than usual,
    /// so the list-fatigue alert shows.
    private static let sends: [(daysAgo: Int, name: String, sent: Int, open: Double, click: Double, unsub: Double)] = [
        (2, "Fall Appeal · Email 3", 46_210, 36.0, 3.2, 0.71),
        (6, "Monthly newsletter", 47_050, 41.0, 5.8, 0.48),
        (10, "Clean Water: take action", 38_900, 44.0, 9.1, 0.52),
        (13, "Fall Appeal · Email 2", 46_480, 37.0, 3.6, 0.22),
        (17, "Harvest Dinner invitation", 12_300, 39.0, 4.4, 0.12),
        (20, "Fall Appeal · Email 1", 46_720, 38.0, 3.9, 0.18),
        (24, "Volunteer thank-you", 8_450, 52.0, 6.2, 0.08),
        (27, "Clean Water: petition update", 38_600, 40.0, 4.8, 0.15),
        (29, "Monthly newsletter", 46_900, 40.5, 4.6, 0.14),
        (33, "Back-to-school appeal · Email 2", 45_800, 38.5, 3.4, 0.19),
        (37, "Monthly newsletter", 46_600, 42.0, 5.1, 0.14),
        (41, "Clean Water: call your rep", 37_900, 43.0, 6.0, 0.17),
        (44, "Back-to-school appeal · Email 1", 45_950, 39.0, 3.3, 0.21),
        (48, "Summer impact report", 46_400, 41.5, 4.0, 0.12),
        (52, "Clean Water: petition launch", 37_500, 45.0, 5.2, 0.16),
        (55, "5K Run reminder", 9_800, 47.0, 7.5, 0.09),
        (58, "Monthly newsletter", 46_300, 40.0, 4.6, 0.15),
        (63, "Midsummer appeal · Email 2", 45_100, 37.5, 3.1, 0.20),
        (67, "Monthly newsletter", 46_000, 41.0, 4.9, 0.13),
        (71, "Midsummer appeal · Email 1", 45_300, 38.0, 3.3, 0.18),
        (75, "Clean Water: share the petition", 37_200, 42.0, 5.5, 0.14),
        (80, "Welcome series update", 6_200, 55.0, 8.1, 0.10),
        (84, "Monthly newsletter", 45_700, 40.5, 4.7, 0.16),
        (88, "Spring results", 45_500, 39.5, 3.9, 0.17),
        (96, "Spring Appeal · Email 4", 45_000, 37.0, 3.0, 0.20),
    ]

    /// startRow and endRow are 1-based and inclusive, as in EN; the default is the newest 20.
    private static func broadcasts(_ parameters: [String: String]) -> Data {
        let all: [[String: String]] = sends.enumerated().map { index, send in
            let day = Calendar.current.date(byAdding: .day, value: -send.daysAgo, to: .now) ?? .now
            func count(_ percent: Double) -> String { String(Int((Double(send.sent) * percent / 100).rounded())) }
            return [
                "broadcastId": String(17_300 - index * 7),
                "broadcastName": send.name,
                "broadcastDate": ENDateFormat.ddMMyyyyString(from: day),
                "sendCount": String(send.sent),
                "openCount": count(send.open),
                "clickCount": count(send.click),
                "unsubscribeCount": count(send.unsub),
            ]
        }
        let first = max(Int(parameters["startRow"] ?? "") ?? 1, 1)
        let last = min(Int(parameters["endRow"] ?? "") ?? 20, all.count)
        guard first <= last else { return rows([]) }
        return rows(Array(all[(first - 1)...(last - 1)]))
    }

    /// A demo donation page: what it takes in a day, and its totals since the campaign began.
    private struct DemoPage {
        let campaignId: Int
        let name: String
        let singlePerDay: Decimal, singleGiftsPerDay: Int
        let recurringPerDay: Decimal, recurringGiftsPerDay: Int
        let single: Decimal, singleGifts: Int
        let recurring: Decimal, recurringGifts: Int
    }

    private static let demoPages: [String: DemoPage] = [
        "71101": DemoPage(campaignId: 5101, name: "Fall Appeal 2026",
                          singlePerDay: 1_950, singleGiftsPerDay: 24, recurringPerDay: 520, recurringGiftsPerDay: 6,
                          single: 142_900, singleGifts: 1_960, recurring: 41_350, recurringGifts: 318),
        "71102": DemoPage(campaignId: 5102, name: "Monthly giving",
                          singlePerDay: 150, singleGiftsPerDay: 3, recurringPerDay: 1_100, recurringGiftsPerDay: 40,
                          single: 4_200, singleGifts: 84, recurring: 38_900, recurringGifts: 1_410),
    ]

    /// Windows ending yesterday or today get the page's usual daily numbers; earlier
    /// windows get 10% less, so changes show. Single days vary between half and one and
    /// a half times the usual, so the daily chart has a shape. A start over a year back
    /// means "the whole campaign" and gets the totals.
    private static func pageGiving(_ parameters: [String: String]) -> Data {
        guard let page = demoPages[parameters["pageid"] ?? ""],
              let start = parameters["startDate"].flatMap(ENDateFormat.iso),
              let end = parameters["endDate"].flatMap(ENDateFormat.iso)
        else { return rows([]) }

        let single: Decimal, singleGifts: Int, recurring: Decimal, recurringGifts: Int
        if end.timeIntervalSince(start) > 366 * 86_400 {
            single = page.single
            singleGifts = page.singleGifts
            recurring = page.recurring
            recurringGifts = page.recurringGifts
        } else {
            let days = Int((end.timeIntervalSince(start) / 86_400).rounded()) + 1
            let isRecent = Date.now.timeIntervalSince(end) < 3 * 86_400
            var share: Decimal = isRecent ? 1 : Decimal(string: "0.9")!
            if days == 1 {
                let dayOfYear = Calendar(identifier: .gregorian).ordinality(of: .day, in: .year, for: start) ?? 1
                share = Decimal(50 + dayOfYear * 37 % 100) / 100
            }
            single = page.singlePerDay * Decimal(days) * share
            recurring = page.recurringPerDay * Decimal(days) * share
            singleGifts = Int((Double(page.singleGiftsPerDay * days) * NSDecimalNumber(decimal: share).doubleValue).rounded())
            recurringGifts = page.recurringGiftsPerDay * days
        }
        func money(_ amount: Decimal) -> String { NSDecimalNumber(decimal: amount).stringValue }
        var row = [
            "ID": String(page.campaignId), "NAME": page.name,
            "TOTAL_NUMBER": String(singleGifts + recurringGifts),
            "TOTAL_NUMBER_SINGLE": String(singleGifts), "TOTAL_NUMBER_RECURRING": String(recurringGifts),
            "TOTAL_AMOUNT_USD": money(single + recurring),
            "TOTAL_AMOUNT_SINGLE_USD": money(single), "TOTAL_AMOUNT_RECURRING_USD": money(recurring),
        ]
        for code in ["GBP", "EUR", "CAD", "AUD"] {
            row["TOTAL_AMOUNT_\(code)"] = "0.00"
            row["TOTAL_AMOUNT_SINGLE_\(code)"] = "0.00"
            row["TOTAL_AMOUNT_RECURRING_\(code)"] = "0.00"
        }
        return rows([row])
    }

    /// Invented donors for the demo campaigns.
    private static func recentGifts(campaignId: String?) -> Data {
        guard campaignId == "5101" || campaignId == "5102" else { return rows([]) }
        return rows([
            ["name": "Maria Garcia", "city": "Toronto", "country": "CA", "currency": "USD", "amount": "50", "additionalComments": ""],
            ["name": "James Thompson", "city": "Seattle", "country": "US", "currency": "USD", "amount": "100", "additionalComments": ""],
            ["name": "anonymous", "city": "Portland", "country": "US", "currency": "USD", "amount": "25", "additionalComments": ""],
            ["name": "Priya Natarajan", "city": "Austin", "country": "US", "currency": "USD", "amount": "250", "additionalComments": ""],
            ["name": "Tom Becker", "city": "Denver", "country": "US", "currency": "USD", "amount": "40", "additionalComments": ""],
            ["name": "Ana Souza", "city": "Boston", "country": "US", "currency": "USD", "amount": "75", "additionalComments": ""],
            ["name": "Grace Kim", "city": "Chicago", "country": "US", "currency": "USD", "amount": "35", "additionalComments": ""],
        ])
    }

    // MARK: JSON helpers

    private static func typeCounts(_ counts: [String: String]) -> Data {
        rows(counts.sorted { $0.key < $1.key }.map { ["Type": $0.key, "Count": $0.value] })
    }

    private static func rows(_ rows: [[String: String]]) -> Data {
        let json: [String: Any] = [
            "rows": rows.map { row in
                ["columns": row.sorted { $0.key < $1.key }.map { ["name": $0.key, "value": $0.value] }]
            },
        ]
        return (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
    }
}
#endif
