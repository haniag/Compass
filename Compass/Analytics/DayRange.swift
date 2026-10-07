//
//  DayRange.swift
//  Compass
//
//  A run of whole calendar days, e.g. "the last 7 days" for Pulse.
//

import Foundation

nonisolated struct DayRange: Hashable, Sendable {
    /// Start of the first day.
    let firstDay: Date
    /// Start of the last day (inclusive).
    let lastDay: Date

    /// The 7 complete days ending yesterday. Today is left out because it isn't over yet,
    /// so this week and the week before are always compared on equal terms.
    static func lastSevenDays(before now: Date, calendar: Calendar = .current) -> DayRange {
        last(7, daysBefore: now, calendar: calendar)
    }

    /// The `count` complete days ending yesterday (Email uses 30).
    static func last(_ count: Int, daysBefore now: Date, calendar: Calendar = .current) -> DayRange {
        let today = calendar.startOfDay(for: now)
        let last = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let first = calendar.date(byAdding: .day, value: -count, to: today) ?? today
        return DayRange(firstDay: first, lastDay: last)
    }

    /// The `count` days ending today, today included (Giving's daily chart shows today's
    /// total so far).
    static func last(_ count: Int, throughToday now: Date, calendar: Calendar = .current) -> DayRange {
        let today = calendar.startOfDay(for: now)
        let first = calendar.date(byAdding: .day, value: -(count - 1), to: today) ?? today
        return DayRange(firstDay: first, lastDay: today)
    }

    /// The start of each day in the range, oldest first.
    func days(calendar: Calendar = .current) -> [Date] {
        var days: [Date] = []
        var day = firstDay
        while day <= lastDay {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    /// True when `date` falls on one of the days in the range.
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        return date >= firstDay && date < end
    }

    /// The same number of days immediately before this range.
    func previous(calendar: Calendar = .current) -> DayRange {
        let length = (calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0) + 1
        return DayRange(
            firstDay: calendar.date(byAdding: .day, value: -length, to: firstDay) ?? firstDay,
            lastDay: calendar.date(byAdding: .day, value: -1, to: firstDay) ?? firstDay
        )
    }

    /// "Sep 17 – 23"
    var label: String {
        (firstDay..<lastDay).formatted(Date.IntervalFormatStyle().month(.abbreviated).day())
    }
}
