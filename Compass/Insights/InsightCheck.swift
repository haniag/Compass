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
            guard wordingProblem(in: draft, citedFacts: citedFacts) == nil,
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

    /// What's wrong with a draft's words, and in which part ("title", "explanation" or
    /// "suggestedAction", the names the model writes them under); nil when the words pass.
    /// Figures are allowed, but only the cited facts' own, as the app shows them.
    /// (`validated` also checks the fact IDs and severity, which Swift sets, not the model.)
    static func wordingProblem(in draft: InsightDraft,
                               citedFacts: [Fact]) -> (part: String, problem: FigureCheck.Problem)? {
        let parts = [("title", draft.title), ("explanation", draft.explanation),
                     ("suggestedAction", draft.suggestedAction ?? "")]
        for (part, text) in parts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty, part != "suggestedAction" { return (part, .empty) }
            if let problem = FigureCheck.problem(quoting: citedFacts, in: trimmed) { return (part, problem) }
        }
        return nil
    }

    /// `written` plus a template insight for every highlight the model didn't cover,
    /// needs-attention first.
    static func filling(_ written: [Insight], highlights: [Fact]) -> [Insight] {
        let covered = Set(written.flatMap(\.factIDs))
        let missing = highlights.filter { !covered.contains($0.id) }
        return (written + TemplateInsights.movers(missing)).sorted { $0.severity.rank < $1.severity.rank }
    }

    // MARK: Rules

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
