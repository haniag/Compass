//
//  SavedBriefing.swift
//  Compass
//
//  Pulse's Apple Intelligence briefing, kept with the exact facts it was written
//  from (one per period), so an unchanged set of numbers doesn't run the model
//  again on the next launch. Only text that passed BriefingCheck is saved. It lives
//  in SavedNumbers, so Disconnect removes it with the other saved numbers.
//

import Foundation
import SwiftData

nonisolated struct SavedBriefing: Codable, Equatable {
    let facts: [Fact]
    let text: String

    static func key(_ period: Fact.Period) -> String { "briefing.\(period.rawValue)" }

    /// The saved briefing when it was written from exactly these facts; nil otherwise.
    @MainActor
    static func text(for facts: [Fact], in context: ModelContext) -> String? {
        guard let period = facts.first?.period,
              let saved = SavedNumbers.load(SavedBriefing.self, key: key(period), in: context)?.value,
              saved.facts == facts
        else { return nil }
        return saved.text
    }

    /// Keeps `text` for these facts, replacing the earlier briefing for their period.
    /// Call only with text that passed BriefingCheck.
    @MainActor
    static func save(_ text: String, facts: [Fact], in context: ModelContext) {
        guard let period = facts.first?.period else { return }
        SavedNumbers.save(SavedBriefing(facts: facts, text: text), as: key(period), in: context)
    }
}
