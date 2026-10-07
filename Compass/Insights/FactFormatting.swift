//
//  FactFormatting.swift
//  Compass
//
//  How a Fact's value and change are written on screen and read by VoiceOver.
//

import Foundation

nonisolated struct FactChange: Hashable, Sendable {
    enum Direction: Hashable, Sendable {
        case up
        case down
        case flat
    }

    let direction: Direction
    /// "13%", "1.4 pts", "214"
    let text: String
    /// "13 percent", "1.4 points", "214"
    let spokenText: String
    /// Nil when flat.
    let isGood: Bool?

    /// "▲ 13%"
    var badgeText: String {
        switch direction {
        case .up: "▲ \(text)"
        case .down: "▼ \(text)"
        case .flat: "No change"
        }
    }

    /// "up 13 percent"
    var spokenSummary: String {
        switch direction {
        case .up: "up \(spokenText)"
        case .down: "down \(spokenText)"
        case .flat: "no change"
        }
    }

    /// "up 13%" for use inside a sentence.
    var phrase: String {
        switch direction {
        case .up: "up \(text)"
        case .down: "down \(text)"
        case .flat: "about the same as"
        }
    }

    /// The relative move between two amounts or counts: 21,740 → 23,480 is "8%".
    /// Nil when the baseline is zero (there's no percent change from nothing).
    static func percent(from baseline: Decimal, to value: Decimal, higherIsBetter: Bool) -> FactChange? {
        guard baseline != 0 else { return nil }
        let percent = NSDecimalNumber(decimal: (value - baseline) / baseline * 100).doubleValue
        let rounded = Int(abs(percent).rounded())
        let direction: Direction = rounded == 0 ? .flat : (percent > 0 ? .up : .down)
        let isGood: Bool? = direction == .flat ? nil : (direction == .up) == higherIsBetter
        return FactChange(direction: direction, text: "\(rounded)%", spokenText: "\(rounded) percent", isGood: isGood)
    }

    /// The move between two rates, in points: 39.6% → 38.2% is "1.4 pts".
    /// Tiny rates like unsubscribes need `decimals: 2` ("0.08 pts").
    static func points(from baseline: Decimal, to value: Decimal, higherIsBetter: Bool, decimals: Int = 1) -> FactChange {
        let difference = NSDecimalNumber(decimal: value - baseline).doubleValue
        let scale = pow(10, Double(decimals))
        let rounded = (abs(difference) * scale).rounded() / scale
        let direction: Direction = rounded == 0 ? .flat : (difference > 0 ? .up : .down)
        let number = rounded.formatted(.number.precision(.fractionLength(decimals)))
        let isGood: Bool? = direction == .flat ? nil : (direction == .up) == higherIsBetter
        return FactChange(direction: direction, text: "\(number) pts", spokenText: "\(number) points", isGood: isGood)
    }
}

nonisolated extension Fact {
    /// "New joins": the tile and chip label.
    var displayName: String {
        switch metric {
        case .supporters: "Supporters"
        case .newJoins: "New joins"
        case .raised: "Raised"
        case .averageGift: "Average gift"
        case .emailOpenRate: "Email opens"
        }
    }

    /// "New joins: 386 in the last 7 days, 342 in the 7 days before (up 13%)."
    /// How a fact is described to the on-device model; it's never shown as-is.
    var summaryLine: String {
        guard let formattedBaseline else {
            return "\(displayName): \(formattedValue)."
        }
        let period = metric == .supporters ? "now" : "in the last 7 days"
        let before = metric == .supporters ? "7 days ago" : "in the 7 days before"
        let change = change.map { " (\($0.direction == .flat ? "no change" : $0.phrase))" } ?? ""
        return "\(displayName): \(formattedValue) \(period), \(formattedBaseline) \(before)\(change)."
    }

    var formattedValue: String { Self.format(value, unit: unit) }

    var formattedBaseline: String? { baseline.map { Self.format($0, unit: unit) } }

    /// Nil when there's nothing to compare with.
    var change: FactChange? {
        guard let difference else { return nil }
        guard let baseline else { return nil }
        if isRate {
            // Rates change in points: 39.6% → 38.2% is "1.4 pts".
            return .points(from: baseline, to: value, higherIsBetter: higherIsBetter)
        }
        if metric == .supporters {
            // Supporters change by people, not percent: "▲ 214 this week".
            let people = abs(NSDecimalNumber(decimal: difference).intValue)
            let direction: FactChange.Direction = people == 0 ? .flat : (difference > 0 ? .up : .down)
            let isGood: Bool? = direction == .flat ? nil : (direction == .up) == higherIsBetter
            return FactChange(direction: direction, text: people.formatted(), spokenText: people.formatted(), isGood: isGood)
        }
        return .percent(from: baseline, to: value, higherIsBetter: higherIsBetter)
    }

    /// "$23,480", "386", "38.2%". Money is in whole amounts, except small averages
    /// where cents matter ($7.50).
    static func format(_ number: Decimal, unit: Unit) -> String {
        switch unit {
        case .count:
            return number.formatted(.number.precision(.fractionLength(0)))
        case .money(let code):
            let digits = number > 0 && number < 10 ? 2 : 0
            return number.formatted(.currency(code: code).precision(.fractionLength(digits)))
        case .percent:
            return (number / 100).formatted(.percent.precision(.fractionLength(1)))
        }
    }
}
