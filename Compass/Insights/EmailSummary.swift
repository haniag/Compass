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
                // The orange banner below already suggests a break; this adds where to look.
                nextStep: "Compare your last \(fatigue.sends) emails with earlier ones: was the ask bigger, or were they sent closer together?",
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

    /// "Opens: 38.2% in the last 30 days, down 1.4 pts from the 30 days before. This needs attention."
    /// The earlier rate itself is left out: the screen doesn't show it, so the summary can't quote it.
    private static func line(_ rate: EmailRate) -> String {
        let now = "\(rate.spokenTitle): \(rate.formattedValue) \(period.during)"
        guard let change = rate.change else { return now + "." }
        let verdict = switch change.isGood {
        case true?: " This is good news."
        case false?: " This needs attention."
        case nil: ""
        }
        let moved = change.direction == .flat ? "the same as \(period.duringBefore)" : "\(change.phrase) from \(period.before)"
        return "\(now), \(moved).\(verdict)"
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
            texts += [rate.formattedValue, rate.change?.text].compactMap { $0 }
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
        // Anything in quotation marks must be the email's name, word for word. The name
        // itself isn't checked for figures or banned words ("Weekly news · Email 3").
        let names = [findings.support?.name].compactMap { $0 }
        guard let rest = NameCheck.replacingNames(names, in: text) else { return false }

        return FigureCheck.quotesOnly(findings.allowedNumbers, period: EmailFindings.period,
                                      showsHalving: false,
                                      showsDoubling: findings.support?.showsDoubling ?? false,
                                      in: rest)
            && agreesOnDirections(rest, rates: findings.rates)
    }

    /// False when the text says a rate "rose 1.6 pts" that fell 1.6 pts, or the other way
    /// round. It looks at the part of the sentence around each change ("…, though clicks
    /// slipped 0.4 pts to 4.9%") for a word that points the wrong way.
    static func agreesOnDirections(_ text: String, rates: [EmailRate]) -> Bool {
        let parts = text.lowercased()
            .split(separator: /[.,;:!?]\s+|\s+(?:and|but|though|although|while|whereas|yet)\s+/)
            .map(String.init)
        let changes = rates.compactMap { rate -> (number: Decimal, isUp: Bool)? in
            guard let change = rate.change, change.direction != .flat,
                  let number = FigureCheck.numbers(in: change.text).first
            else { return nil }
            return (number, change.direction == .up)
        }
        for change in changes {
            // Two rates that moved by the same amount in opposite directions can't be told apart.
            if changes.contains(where: { $0.number == change.number && $0.isUp != change.isUp }) { continue }
            for part in parts where FigureCheck.numbers(in: part).contains(change.number) {
                let words = Set(part.split { !$0.isLetter }.map(String.init))
                let right = change.isUp ? upWords : downWords
                let wrong = change.isUp ? downWords : upWords
                if !words.isDisjoint(with: wrong), words.isDisjoint(with: right) { return false }
            }
        }
        return true
    }

    private static let upWords: Set<String> = [
        "up", "rose", "rise", "risen", "rising", "climbed", "climbing", "grew", "grown", "growing",
        "increased", "increase", "higher", "gained", "jumped",
    ]
    private static let downWords: Set<String> = [
        "down", "fell", "fall", "fallen", "falling", "slipped", "slipping", "dropped", "drop",
        "dropping", "declined", "decreased", "decrease", "dipped", "lower", "slid", "lost",
    ]
}
