//
//  TemplateInsights.swift
//  Compass
//
//  Insights written from fixed templates: Pulse's top insight, the digest when
//  Apple Intelligence isn't available, and the digest's steady note. Every number
//  comes from a Fact.
//

import Foundation

nonisolated enum TemplateInsights {
    /// Pulse's "Top insight": the biggest mover, or a steady note. Nil with no facts.
    static func pulse(facts: [Fact]) -> Insight? {
        if let fact = InsightRules.pulseHighlight(from: facts), let insight = insight(about: fact) {
            return insight
        }
        return steady(facts.filter { $0.metric != .supporters }, othersMoved: false)
    }

    /// The Insights tab's digest: one insight per fact that moved, needs-attention
    /// first, then a steady note for the rest. Empty with no facts.
    static func digest(facts: [Fact]) -> [Insight] {
        let highlights = InsightRules.highlights(from: facts)
        return movers(highlights) + [steadyNote(facts: facts, highlights: highlights)].compactMap { $0 }
    }

    /// One insight per highlighted fact, needs-attention first.
    static func movers(_ highlights: [Fact]) -> [Insight] {
        highlights.compactMap(insight(about:)).sorted { $0.severity.rank < $1.severity.rank }
    }

    /// The facts that didn't make the highlights, as one "steady" insight.
    static func steadyNote(facts: [Fact], highlights: [Fact]) -> Insight? {
        let highlighted = Set(highlights.map(\.id))
        let quiet = facts.filter { $0.metric != .supporters && !highlighted.contains($0.id) }
        return steady(quiet, othersMoved: !highlights.isEmpty)
    }

    private static func insight(about fact: Fact) -> Insight? {
        guard let change = fact.change, change.direction != .flat else { return nil }
        let rising = change.direction == .up
        return Insight(
            id: "template.\(fact.id)",
            title: title(for: fact, rising: rising),
            severity: severity(for: fact),
            factIDs: [fact.id],
            explanation: explanation(for: fact, change: change),
            suggestedAction: action(for: fact.metric, rising: rising)
        )
    }

    private static func steady(_ facts: [Fact], othersMoved: Bool) -> Insight? {
        guard !facts.isEmpty else { return nil }
        let names = facts.map(\.plainName).formatted(.list(type: .and))
        let verb = facts.count == 1 && !facts[0].plainName.hasSuffix("s") ? "is" : "are"
        let period = facts[0].period
        return Insight(
            id: "template.steady",
            title: othersMoved ? "Everything else held steady" : "A steady \(period.span)",
            severity: .neutral,
            factIDs: facts.map(\.id),
            explanation: "Your \(names) \(verb) close to \(period.before).".capitalizedFirst,
            suggestedAction: nil
        )
    }

    /// The template's next step for a fact, e.g. as a starting idea for the on-device model.
    static func suggestedAction(for fact: Fact) -> String? {
        guard let change = fact.change, change.direction != .flat else { return nil }
        return action(for: fact.metric, rising: change.direction == .up)
    }

    /// Worse is "needs attention". Rising new joins are an opportunity: new people to
    /// welcome while they're paying attention. Other improvements are good news.
    static func severity(for fact: Fact) -> Insight.Severity {
        guard let change = fact.change, change.direction != .flat else { return .neutral }
        guard change.isGood ?? true else { return .attention }
        return fact.metric == .newJoins ? .opportunity : .good
    }

    // MARK: Wording

    private static func title(for fact: Fact, rising: Bool) -> String {
        let during = fact.period.during
        switch (fact.metric, rising) {
        case (.newJoins, true): return "More people joined \(during)"
        case (.newJoins, false): return "Fewer people joined \(during)"
        case (.raised, true): return "Giving rose \(during)"
        case (.raised, false): return "Giving dipped \(during)"
        case (.averageGift, true): return "Gifts were larger \(during)"
        case (.averageGift, false): return "Gifts were smaller \(during)"
        case (.emailOpenRate, true): return "More people opened your emails"
        case (.emailOpenRate, false): return "Fewer people opened your emails"
        // Supporters is a count now vs one period ago: "grew in the last month".
        case (.supporters, true): return "Your list grew in the last \(fact.period.span)"
        case (.supporters, false): return "Your list shrank in the last \(fact.period.span)"
        }
    }

    private static func explanation(for fact: Fact, change: FactChange) -> String {
        let before = fact.formattedBaseline ?? ""
        let during = fact.period.during
        let comparison = "\(change.phrase) from \(before) \(fact.period.duringBefore)"
        switch fact.metric {
        case .newJoins:
            return "\(fact.formattedValue) people joined \(during), \(comparison)."
        case .raised:
            return "You raised \(fact.formattedValue) \(during), \(comparison)."
        case .averageGift:
            return "Your average gift was \(fact.formattedValue) \(during), \(comparison)."
        case .emailOpenRate:
            return "\(fact.formattedValue) of people opened your emails \(during), \(comparison)."
        case .supporters:
            return "You have \(fact.formattedValue) supporters, \(change.phrase) from \(before) \(fact.period.spanAgo)."
        }
    }

    private static func action(for metric: Fact.Metric, rising: Bool) -> String? {
        switch (metric, rising) {
        case (.newJoins, true): "Send new supporters a warm welcome email while they’re paying attention."
        case (.newJoins, false): "Share your most popular action again, in your next email or on social media."
        case (.raised, true): "Thank recent donors quickly — a prompt thank-you makes a second gift more likely."
        case (.raised, false): "Send a short reminder to supporters who opened your last appeal but didn’t give."
        case (.averageGift, true): "Check which appeal brought in the larger gifts and reuse its ask amounts."
        case (.averageGift, false): "Review the suggested amounts on your donation pages."
        case (.emailOpenRate, true): "Note what worked in your recent subject lines and try it again."
        case (.emailOpenRate, false): "Try a shorter, more personal subject line on your next email."
        case (.supporters, _): nil
        }
    }
}

nonisolated extension Insight.Severity {
    /// Display order in the digest: needs attention first.
    var rank: Int {
        switch self {
        case .attention: 0
        case .opportunity: 1
        case .good: 2
        case .neutral: 3
        }
    }
}

nonisolated private extension Fact {
    /// "new supporters", "giving"… for sentences.
    var plainName: String {
        switch metric {
        case .supporters: "supporters"
        case .newJoins: "new supporters"
        case .raised: "giving"
        case .averageGift: "average gift"
        case .emailOpenRate: "email opens"
        }
    }
}

extension String {
    /// "The 7 days before" from "the 7 days before".
    nonisolated var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
