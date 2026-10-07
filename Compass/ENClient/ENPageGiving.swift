//
//  ENPageGiving.swift
//  Compass
//
//  One row of FundraisingSummaryByPage: gifts through one page between two days.
//  EN reports amounts in USD, GBP, EUR, CAD and AUD only, leaves out test gifts,
//  and sends no row at all when there were no gifts (verified on the test account).
//

import Foundation

nonisolated struct ENPageGiving: Hashable, Sendable {
    static let currencies = ["USD", "GBP", "EUR", "CAD", "AUD"]

    let campaignId: Int
    let name: String
    let gifts: Int
    let singleGifts: Int
    /// Counts recurring *gifts* (each charge), not recurring donors.
    let recurringGifts: Int
    /// Amounts by currency code.
    let raised: [String: Decimal]
    let raisedSingle: [String: Decimal]
    let raisedRecurring: [String: Decimal]

    init(campaignId: Int, name: String, gifts: Int, singleGifts: Int, recurringGifts: Int,
         raised: [String: Decimal], raisedSingle: [String: Decimal], raisedRecurring: [String: Decimal]) {
        self.campaignId = campaignId
        self.name = name
        self.gifts = gifts
        self.singleGifts = singleGifts
        self.recurringGifts = recurringGifts
        self.raised = raised
        self.raisedSingle = raisedSingle
        self.raisedRecurring = raisedRecurring
    }

    init?(row: ENRow) {
        guard let campaignId = row.int("ID") else { return nil }
        func amounts(_ prefix: String) -> [String: Decimal] {
            var byCurrency: [String: Decimal] = [:]
            for code in Self.currencies {
                if let amount = row.decimal("\(prefix)_\(code)") {
                    byCurrency[code] = amount
                }
            }
            return byCurrency
        }
        self.init(
            campaignId: campaignId,
            name: row.string("NAME") ?? "Campaign \(campaignId)",
            gifts: row.int("TOTAL_NUMBER") ?? 0,
            singleGifts: row.int("TOTAL_NUMBER_SINGLE") ?? 0,
            recurringGifts: row.int("TOTAL_NUMBER_RECURRING") ?? 0,
            raised: amounts("TOTAL_AMOUNT"),
            raisedSingle: amounts("TOTAL_AMOUNT_SINGLE"),
            raisedRecurring: amounts("TOTAL_AMOUNT_RECURRING")
        )
    }
}
