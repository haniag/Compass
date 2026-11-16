//
//  EmailSummary.swift
//  Compass
//
//  The words for the Email tab's summary card: how EmailFindings are described to the
//  on-device model, the plain summary shown without Apple Intelligence, and the check
//  every model-written summary has to pass.
//

import Foundation

nonisolated extension EmailFindings {
    /// Email always compares the last 30 days with the 30 before (`EmailViewModel.windowDays`).
    static let period = Fact.Period.lastThirtyDays

    /// The one thing besides the rates that the summary talks about, and the next step
    /// that goes with it. Swift picks it; the model only words it.
    struct Support: Hashable, Sendable {
        /// How it's described to the model.
        let line: String
        /// What to do about it, in plain words, with no figures.
        let nextStep: String
        /// The email it names, if any.
        var name: String?
        /// Its figures as written in `line`, so the check knows them.
        var figures: [String] = []
        /// True when "twice" is a fair word for it.
        var showsDoubling = false
    }

    /// The most pressing first: list fatigue, then one email that lost supporters, then
    /// what went well.
    var support: Support? {
        if let fatigue {
            return Support(
                line: "Warning: each of the last \(fatigue.sends) emails lost supporters at about \(fatigue.timesUsual) times the usual rate.",
                nextStep: "Give your list a short break, or make a gentler ask, before the next email.",
                figures: ["\(fatigue.sends)", "\(fatigue.timesUsual)"],
                showsDoubling: fatigue.timesUsual == 2
            )
        }
        if let send = highUnsubscribeSend {
            let rate = EmailFormat.compactPercent(send.rate)
            return Support(
                line: "Lost the most supporters: “\(send.name)”, with a \(rate) unsubscribe rate.",
                nextStep: "Look at what was different about “\(send.name)”, which lost more supporters than usual.",
                name: send.name,
                figures: [rate]
            )
        }
        if let send = bestSend {
            let rate = EmailFormat.compactPercent(send.rate)
            return Support(
                line: "Best email: “\(send.name)”, with a \(rate) click rate.",
                nextStep: "See what worked in “\(send.name)”, your most-clicked email, and try it again.",
                name: send.name,
                figures: [rate]
            )
        }
        if let day = bestWeekday, let clickRate = day.clickRate {
            let name = Calendar.current.weekdaySymbols[day.weekday - 1]
            let rate = EmailFormat.compactPercent(clickRate)
            return Support(
                line: "Best day to send: \(name), with a \(rate) click rate.",
                nextStep: "Try sending your next email on a \(name), your best day for clicks.",
                figures: [rate]
            )
        }
        return nil
    }

    /// What the on-device model is given: one line per rate, how many emails went out,
    /// and the supporting line. Never shown as-is.
    var promptLines: [String] {
        let sent = "Emails sent \(Self.period.during): \(sendsInPeriod)."
        return rates.map(Self.line) + [sent] + [support?.line].compactMap { $0 }
    }

    /// "Opens: 38.2% in the last 30 days, 39.6% in the 30 days before (down 1.4 pts). This needs attention."
    private static func line(_ rate: EmailRate) -> String {
        let now = "\(rate.spokenTitle): \(rate.formattedValue) \(period.during)"
        guard let baseline = rate.formattedBaseline, let change = rate.change else { return now + "." }
        let verdict = switch change.isGood {
        case true?: " This is good news."
        case false?: " This needs attention."
        case nil: ""
        }
        return "\(now), \(baseline) \(period.duringBefore) (\(moved(change))).\(verdict)"
    }

    private static func moved(_ change: FactChange) -> String {
        change.direction == .flat ? "no change" : change.phrase
    }

    /// The summary without Apple Intelligence: "Opens were 38.2% in the last 30 days,
    /// down 1.4 pts, and clicks were 3.1%, up 0.4 pts." plus the next step.
    var template: String {
        let shown = rates.filter { $0.kind != .unsubscribes }
        let parts = (shown.isEmpty ? rates : shown).enumerated().map { index, rate in
            let title = index == 0 ? rate.spokenTitle : rate.spokenTitle.lowercased()
            let during = index == 0 ? " \(Self.period.during)" : ""
            let change = rate.change.map { ", \(Self.moved($0))" } ?? ""
            return "\(title) were \(rate.formattedValue)\(during)\(change)"
        }
        let overview = parts.joined(separator: ", and ") + "."
        return [overview, support?.nextStep].compactMap { $0 }.joined(separator: " ")
    }

    /// Every number a summary may quote: the figures above, plus the 30 in "last 30 days".
    var allowedNumbers: Set<Decimal> {
        var texts = ["\(Self.period.during) \(Self.period.before)", "\(sendsInPeriod)"]
        for rate in rates {
            texts += [rate.formattedValue, rate.formattedBaseline, rate.change?.text].compactMap { $0 }
        }
        texts += support?.figures ?? []
        return Set(texts.flatMap(FigureCheck.numbers))
    }
}

/// A model-written summary may quote figures and name one email, but only the ones
/// Swift handed over.
nonisolated enum EmailSummaryCheck {
    /// No more than this many words: about two sentences.
    static let maxWords = 70

    static func isSafe(_ text: String, findings: EmailFindings) -> Bool {
        guard !text.isEmpty, text.split(separator: " ").count <= maxWords else { return false }
        let name = findings.support?.name

        // Anything in quotation marks must be the email's name, word for word.
        var rest = text.replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"")
        for match in rest.matches(of: /"([^"]*)"/) {
            let quoted = String(match.output.1).trimmingCharacters(in: .whitespaces)
            // American style puts the comma inside the quotation marks.
            let withoutComma = quoted.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
            guard let name, quoted == name || withoutComma == name else { return false }
        }
        // The name itself isn't checked for figures or banned words ("Weekly news · Email 3").
        rest = rest.replacing(/"[^"]*"/, with: " ")
        if let name {
            rest = rest.replacingOccurrences(of: name, with: " ", options: .caseInsensitive)
        }
        guard !rest.contains("\"") else { return false }

        return FigureCheck.quotesOnly(findings.allowedNumbers, period: EmailFindings.period,
                                      showsHalving: false,
                                      showsDoubling: findings.support?.showsDoubling ?? false,
                                      in: rest)
    }
}
