//
//  ENRecentGift.swift
//  Compass
//
//  One row of FundraisingRollCall: a gift to a campaign in the last 7 days.
//  The donor's name and city are personal data: show them in the app, never save
//  them, and keep them out of widgets. EN's free-text comments column is never read.
//

import Foundation

nonisolated struct ENRecentGift: Hashable, Sendable {
    /// As EN sends it: first and last name, or "anonymous".
    let name: String
    let city: String?
    let currency: String
    let amount: Decimal

    init(name: String, city: String?, currency: String, amount: Decimal) {
        self.name = name
        self.city = city
        self.currency = currency
        self.amount = amount
    }

    init?(row: ENRow) {
        guard let amount = row.decimal("amount") else { return nil }
        self.init(
            name: row.string("name") ?? "anonymous",
            city: row.string("city"),
            currency: row.string("currency")?.uppercased() ?? AccountSettings.reportingCurrency,
            amount: amount
        )
    }

    var isAnonymous: Bool { name.caseInsensitiveCompare("anonymous") == .orderedSame }

    /// "Maria G.": first name and last initial, as in the comps. "Anonymous" stays anonymous.
    var shortName: String {
        let parts = name.split(separator: " ")
        guard !isAnonymous, let first = parts.first else { return "Anonymous" }
        guard parts.count > 1, let initial = parts.last?.first else { return String(first) }
        return "\(first) \(initial)."
    }
}
