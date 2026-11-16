//
//  GivingSummary.swift
//  Compass
//
//  The words for the "All pages" summary on Giving: how GivingFindings are described
//  to the on-device model, the plain summary shown without Apple Intelligence, and the
//  check every model-written summary has to pass.
//

import Foundation

nonisolated extension GivingFindings {
    /// "in the last 30 days", or "so far" for the whole campaign.
    var during: String {
        days.map { "in the last \($0) days" } ?? "so far"
    }

    /// For the wording rules FigureCheck applies. Nil for the whole campaign.
    var period: Fact.Period? {
        switch days {
        case 7: .lastSevenDays
        case 30: .lastThirtyDays
        default: nil
        }
    }

    var formattedTotal: String { money(total) }
    var formattedTop: String { money(top.raised) }

    /// The top page's name, when it can be quoted.
    var topName: String? { NameCheck.quotable(top.name) }

    /// The one quiet page's name, when there's exactly one and it can be quoted.
    var quietName: String? {
        quiet.count == 1 ? NameCheck.quotable(quiet[0].name) : nil
    }

    /// The page names a summary may use, in placeholder order (see `NameCheck`).
    var names: [String] { [topName, quietName].compactMap { $0 } }

    private func money(_ amount: Decimal) -> String {
        Fact.format(amount, unit: .money(currencyCode: currency))
    }

    private var topLabel: String { topName.map { "“\($0)”" } ?? "your top page" }

    /// What the on-device model is given. Never shown as-is.
    var promptLines: [String] {
        var lines = [
            "All \(pageCount) pages together: \(formattedTotal) raised \(during).",
            "Top page: \(topName.map { "“\($0)”, with " } ?? "")\(formattedTop) raised \(during).",
        ]
        if let quietName {
            lines.append("No gifts \(during): “\(quietName)”.")
        } else if !quiet.isEmpty {
            lines.append("Pages with no gifts \(during): \(quiet.count).")
        }
        return lines
    }

    /// What to do next, in plain words, with no amounts. Quiet pages come first.
    var nextStep: String {
        if let quietName {
            return "Check that the link to “\(quietName)” is still being shared; it brought in no gifts \(during)."
        }
        if !quiet.isEmpty {
            return "Check that the links to your quiet pages are still being shared."
        }
        return "Look at what \(topLabel) is doing well and try it on your other pages."
    }

    /// The summary without Apple Intelligence.
    var template: String {
        "Your \(pageCount) pages raised \(formattedTotal) together \(during), led by \(topLabel) with \(formattedTop). \(nextStep)"
    }

    /// Every number a summary may quote.
    var allowedNumbers: Set<Decimal> {
        var texts = [during, "\(pageCount)", formattedTotal, formattedTop]
        if quiet.count > 1 { texts.append("\(quiet.count)") }
        // "raised $0" is fair to say of a quiet page.
        if !quiet.isEmpty { texts.append("0") }
        return Set(texts.flatMap(FigureCheck.numbers))
    }
}

/// A model-written summary may quote the total and the top page's amount, and name
/// only the pages Swift handed over.
nonisolated enum GivingSummaryCheck {
    /// No more than this many words: about two sentences.
    static let maxWords = 70

    static func isSafe(_ text: String, findings: GivingFindings) -> Bool {
        guard !text.isEmpty, text.split(separator: " ").count <= maxWords,
              let rest = NameCheck.replacingNames(findings.names, in: text)
        else { return false }

        return FigureCheck.quotesOnly(findings.allowedNumbers, period: findings.period,
                                      showsHalving: false, showsDoubling: false, in: rest)
            && keepsAmountsWithTheirPages(rest, findings: findings)
    }

    /// False when the text gives the top page the total ("“Fall Appeal” raised $31,000"
    /// when that's what all pages raised), or a quiet page any amount but $0.
    static func keepsAmountsWithTheirPages(_ text: String, findings: GivingFindings) -> Bool {
        let total = FigureCheck.numbers(in: findings.formattedTotal).first
        let top = FigureCheck.numbers(in: findings.formattedTop).first
        let topWord = findings.topName.map { _ in NameCheck.placeholder(0) }
        let quietWord = findings.quietName.map { _ in NameCheck.placeholder(findings.topName == nil ? 0 : 1) }
        let parts = text.lowercased()
            .split(separator: /[.,;:!?]\s+|\s+(?:and|but|though|although|while|whereas|yet)\s+/)
            .map(String.init)
        for part in parts {
            let words = Set(part.split { !$0.isLetter }.map(String.init))
            let numbers = Set(FigureCheck.numbers(in: part))
            if let topWord, words.contains(topWord), let total, let top, total != top,
               numbers.contains(total), !numbers.contains(top) {
                return false
            }
            if let quietWord, words.contains(quietWord), let total, let top,
               numbers.contains(total) || numbers.contains(top) {
                return false
            }
        }
        return true
    }
}
