//
//  SupporterSnapshot.swift
//  Compass
//
//  EaSupporterCount only gives today's total, so Compass saves it on each refresh
//  (one per day) to build the supporter trend over time.
//

import Foundation
import SwiftData

@Model
final class SupporterSnapshot {
    var takenAt: Date
    var count: Int

    init(takenAt: Date, count: Int) {
        self.takenAt = takenAt
        self.count = count
    }

    /// Saves today's count, replacing an earlier snapshot from the same day.
    static func record(_ count: Int, at date: Date = .now, in context: ModelContext) {
        var latest = FetchDescriptor<SupporterSnapshot>(sortBy: [SortDescriptor(\.takenAt, order: .reverse)])
        latest.fetchLimit = 1
        if let existing = try? context.fetch(latest).first,
           Calendar.current.isDate(existing.takenAt, inSameDayAs: date) {
            existing.takenAt = date
            existing.count = count
        } else {
            context.insert(SupporterSnapshot(takenAt: date, count: count))
        }
        try? context.save()
    }

    /// Snapshots from the last `weeks` weeks (plus one extra day), oldest first.
    static func recent(weeks: Int, before date: Date = .now, in context: ModelContext) -> [SupporterSnapshot] {
        let cutoff = date.addingTimeInterval(-Double(weeks * 7 + 1) * 86_400)
        let descriptor = FetchDescriptor<SupporterSnapshot>(
            predicate: #Predicate { $0.takenAt >= cutoff },
            sortBy: [SortDescriptor(\.takenAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    #if DEBUG
    /// Demo mode: fill in 12 weeks of fake history the first time.
    static func seedDemoHistoryIfEmpty(in context: ModelContext, now: Date = .now) {
        guard ((try? context.fetchCount(FetchDescriptor<SupporterSnapshot>())) ?? 0) == 0 else { return }
        let history = ENDemoData.weeklySupporterHistory
        for (index, count) in history.enumerated() {
            let weeksAgo = history.count - index
            // An hour earlier than exactly N weeks ago, so "a week ago" always finds one.
            let date = now.addingTimeInterval(-Double(weeksAgo) * 7 * 86_400 - 3_600)
            context.insert(SupporterSnapshot(takenAt: date, count: count))
        }
        try? context.save()
    }
    #endif
}
