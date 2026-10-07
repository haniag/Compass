//
//  InsightCheck.swift
//  Compass
//
//  Checks what the on-device model wrote before it reaches the screen. The model
//  only words things: anything that cites an unknown fact, quotes a number that
//  isn't one of its fact's figures, speaks as "we", or disagrees with the
//  direction of the figures is dropped.
//

import Foundation

/// An insight as the model wrote it, before it's checked.
nonisolated struct InsightDraft: Hashable, Sendable {
    var title: String
    var severity: Insight.Severity
    var factIDs: [String]
    var explanation: String
    var suggestedAction: String?
}

/// A checked answer to an "Ask about your numbers" question.
nonisolated struct NumbersAnswer: Hashable, Sendable {
    let text: String
    /// Facts to show as figures under the answer.
    let factIDs: [String]
}

nonisolated enum InsightCheck {
    /// The drafts that are safe to show, as insights. Unknown fact IDs are removed first.
    static func validated(_ drafts: [InsightDraft], facts: [Fact]) -> [Insight] {
        var seen: Set<[String]> = []
        return drafts.enumerated().compactMap { index, draft in
            let cited = knownIDs(draft.factIDs, in: facts)
            guard !cited.isEmpty, seen.insert(cited.sorted()).inserted else { return nil }

            let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let explanation = draft.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
            let action = draft.suggestedAction?.trimmingCharacters(in: .whitespacesAndNewlines)
            let citedFacts = cited.compactMap { id in facts.first { $0.id == id } }
            // Figures are allowed, but only this insight's own, as the app shows them.
            guard !title.isEmpty, !explanation.isEmpty,
                  [title, explanation, action ?? ""].allSatisfy({ FigureCheck.quotesOnlyFigures(of: citedFacts, in: $0) }),
                  severity(draft.severity, agreesWith: citedFacts)
            else { return nil }

            return Insight(
                id: "ai.\(index)",
                title: title,
                severity: draft.severity,
                factIDs: cited,
                explanation: explanation,
                suggestedAction: action?.isEmpty == false ? action : nil,
                isGenerated: true
            )
        }
    }

    /// `written` plus a template insight for every highlight the model didn't cover,
    /// needs-attention first.
    static func filling(_ written: [Insight], highlights: [Fact]) -> [Insight] {
        let covered = Set(written.flatMap(\.factIDs))
        let missing = highlights.filter { !covered.contains($0.id) }
        return (written + TemplateInsights.movers(missing)).sorted { $0.severity.rank < $1.severity.rank }
    }

    /// An answer that's safe to show. Text with numbers in it is replaced, because
    /// figures must come from the facts; the cited facts are shown instead.
    static func answer(text: String, factIDs: [String], facts: [Fact]) -> NumbersAnswer {
        let cited = knownIDs(factIDs, in: facts)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, isSafeCopy(trimmed) {
            return NumbersAnswer(text: trimmed, factIDs: cited)
        }
        if !cited.isEmpty {
            return NumbersAnswer(text: "Here are the figures that answer your question.", factIDs: cited)
        }
        return NumbersAnswer(text: cantAnswer, factIDs: [])
    }

    static let cantAnswer = "I can’t answer that from your numbers yet. Try asking about new joins, giving, average gift or email opens."

    // MARK: Rules

    /// For "Ask about your numbers" answers, which may not contain figures at all.
    /// Words the model may not use:
    /// - no digits or amounts in words ("half", "twice"): figures come from facts;
    /// - no "week": the app compares the last 7 days with the 7 days before and says so itself;
    /// - no "we" / "our": the app speaks to the team, it isn't part of it.
    static func isSafeCopy(_ text: String) -> Bool {
        let words = Set(text.lowercased()
            .split { !$0.isLetter && $0 != "’" && $0 != "'" }
            .map { $0.replacingOccurrences(of: "’", with: "'") })
        return !text.contains(where: \.isNumber) && words.isDisjoint(with: bannedWords)
    }

    private static let bannedWords: Set<String> = [
        // Speaking as the organization.
        "we", "we're", "we've", "we'll", "us", "our", "ours", "let's",
        // Time periods the app shows itself.
        "week", "weeks", "week's", "weekly",
        // Quantities worked out by the model, or numbers spelled out ("four members").
        // "one" is allowed: it's common in plain sentences ("one more gift").
        "half", "halved", "double", "doubled", "twice", "triple", "tripled",
        "third", "quarter", "percent", "percentage",
        "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "twenty", "thirty", "forty", "fifty", "hundred",
        "hundreds", "thousand", "thousands", "million", "millions", "dozen", "dozens",
    ]

    /// Good news and opportunities can't be about a number that got worse, and
    /// "needs attention" must be about one that did.
    static func severity(_ severity: Insight.Severity, agreesWith facts: [Fact]) -> Bool {
        let worse = facts.contains { $0.change?.isGood == false }
        switch severity {
        case .good, .opportunity: return !worse
        case .attention: return worse
        case .neutral: return true
        }
    }

    private static func knownIDs(_ ids: [String], in facts: [Fact]) -> [String] {
        var seen: Set<String> = []
        return ids.filter { id in facts.contains { $0.id == id } && seen.insert(id).inserted }
    }
}
