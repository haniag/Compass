//
//  EmailRate.swift
//  Compass
//
//  One email rate (opens, clicks or unsubscribes) for a window of days, and the same
//  rate in the window before. Rates are percent of emails sent.
//

import Foundation

nonisolated struct EmailRate: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case opens
        case clicks
        case unsubscribes
    }

    let kind: Kind
    /// 38.2 means 38.2%.
    let value: Decimal
    /// The rate in the window before. Nil when nothing was sent then.
    let baseline: Decimal?

    var id: Kind { kind }

    /// Fewer unsubscribes is the good direction.
    var higherIsBetter: Bool { kind != .unsubscribes }

    /// Short label, as in the comps.
    var title: String {
        switch kind {
        case .opens: "Opens"
        case .clicks: "Clicks"
        case .unsubscribes: "Unsubs"
        }
    }

    /// What VoiceOver reads instead of `title`.
    var spokenTitle: String {
        switch kind {
        case .opens: "Opens"
        case .clicks: "Clicks"
        case .unsubscribes: "Unsubscribes"
        }
    }

    /// "38.2%", or "0.24%" for rates under 1%.
    var formattedValue: String { EmailFormat.percent(value, decimals: decimals) }

    /// "▼ 1.4 pts". Nil when there's nothing to compare with.
    var change: FactChange? {
        baseline.map { FactChange.points(from: $0, to: value, higherIsBetter: higherIsBetter, decimals: decimals) }
    }

    /// Unsubscribe rates are tiny, so rates under 1% get two decimals.
    private var decimals: Int { max(value, baseline ?? value) < 1 ? 2 : 1 }
}

nonisolated enum EmailFormat {
    /// 38.2 → "38.2%".
    static func percent(_ value: Decimal, decimals: Int) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(decimals)))
    }

    /// For one send's row, where space is tight: "36%", "3.2%", "0.71%", "0%".
    static func compactPercent(_ value: Decimal) -> String {
        let decimals = value == 0 || value >= 10 ? 0 : (value >= 1 ? 1 : 2)
        return percent(value, decimals: decimals)
    }
}
