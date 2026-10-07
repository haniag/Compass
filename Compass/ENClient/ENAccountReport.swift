//
//  ENAccountReport.swift
//  Compass
//
//  Typed results of AccountReports. Most result types come back as
//  rows of { Type: "total", Count: "386" }; netdonoramounts has one row per currency.
//

import Foundation

nonisolated enum ENAccountReportType: String, Sendable {
    case newJoins = "newjoins"
    case accountTotals = "accounttotals"
    case donorTransactions = "netdonortransactions"
    case donorAmounts = "netdonoramounts"
    case broadcastStats = "broadcaststats"
}

/// Gifts received in one currency during the report window.
nonisolated struct ENDonationAmount: Hashable, Sendable {
    let currency: String
    let total: Decimal
    let average: Decimal

    init(currency: String, total: Decimal, average: Decimal) {
        self.currency = currency
        self.total = total
        self.average = average
    }

    init?(row: ENRow) {
        guard let currency = row.string("Currency")?.uppercased(), let total = row.decimal("Total") else { return nil }
        self.init(currency: currency, total: total, average: row.decimal("Average") ?? 0)
    }
}

/// Email totals for the report window.
nonisolated struct ENBroadcastStats: Hashable, Sendable {
    let emailsSent: Int
    /// Percent, e.g. 38.2. Nil when nothing was sent.
    let openRate: Decimal?
}

extension Array where Element == ENRow {
    /// Type/Count rows as a dictionary keyed by the lowercased Type.
    nonisolated var typeCounts: [String: Decimal] {
        var counts: [String: Decimal] = [:]
        for row in self {
            if let type = row.string("Type")?.lowercased(), let count = row.decimal("Count") {
                counts[type] = count
            }
        }
        return counts
    }
}
