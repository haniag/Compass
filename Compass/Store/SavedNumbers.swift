//
//  SavedNumbers.swift
//  Compass
//
//  The last numbers each screen loaded, kept on the device so the app opens with
//  something to show (and works offline). One entry per key, e.g. "pulse.lastSevenDays".
//  Totals and email sends only: never names, cities or the token.
//

import Foundation
import SwiftData

@Model
final class SavedNumbers {
    @Attribute(.unique) var key: String
    var savedAt: Date
    /// The numbers, as JSON.
    var payload: Data

    init(key: String, savedAt: Date, payload: Data) {
        self.key = key
        self.savedAt = savedAt
        self.payload = payload
    }

    /// Saves `value` under `key`, replacing what was there.
    static func save<Value: Encodable>(_ value: Value, as key: String, at date: Date = .now, in context: ModelContext) {
        guard let payload = try? JSONEncoder().encode(value) else { return }
        if let existing = entry(key, in: context) {
            existing.savedAt = date
            existing.payload = payload
        } else {
            context.insert(SavedNumbers(key: key, savedAt: date, payload: payload))
        }
        try? context.save()
    }

    /// What was saved under `key` and when. Nil when there's nothing, or it was saved
    /// by a version of the app that stored it differently.
    static func load<Value: Decodable>(_ type: Value.Type, key: String, in context: ModelContext) -> (value: Value, savedAt: Date)? {
        guard let entry = entry(key, in: context),
              let value = try? JSONDecoder().decode(type, from: entry.payload)
        else { return nil }
        return (value, entry.savedAt)
    }

    private static func entry(_ key: String, in context: ModelContext) -> SavedNumbers? {
        try? context.fetch(FetchDescriptor<SavedNumbers>(predicate: #Predicate { $0.key == key })).first
    }
}
