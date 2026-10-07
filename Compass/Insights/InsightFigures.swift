//
//  InsightFigures.swift
//  Compass
//
//  The small number chips under an insight ("386 · last 7 days"). They're built
//  from the insight's facts, so every figure on screen was computed in Swift.
//

import Foundation

nonisolated struct InsightFigure: Hashable, Sendable {
    /// "386"
    let value: String
    /// "last 7 days"
    let label: String
}

nonisolated extension InsightFigure {
    /// One fact: its value and what it's compared with. Several facts: one chip each.
    /// Fact IDs that aren't in `facts` are skipped.
    static func figures(for factIDs: [String], in facts: [Fact]) -> [InsightFigure] {
        let cited = factIDs.compactMap { id in facts.first { $0.id == id } }
        guard cited.count == 1, let fact = cited.first else {
            return cited.map { InsightFigure(value: $0.formattedValue, label: $0.displayName.lowercased()) }
        }
        let now = fact.metric == .supporters ? "now" : fact.period.title.lowercased()
        let before = fact.metric == .supporters ? fact.period.spanAgo : fact.period.before
        var figures = [InsightFigure(value: fact.formattedValue, label: now)]
        if let baseline = fact.formattedBaseline {
            figures.append(InsightFigure(value: baseline, label: before))
        }
        return figures
    }
}
