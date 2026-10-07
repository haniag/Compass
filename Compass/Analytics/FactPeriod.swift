//
//  FactPeriod.swift
//  Compass
//
//  Which days each Pulse period covers, and what it's compared with.
//

import Foundation

nonisolated extension Fact.Period {
    /// The days this period covers, ending yesterday at the latest.
    func range(before now: Date, calendar: Calendar = .current) -> DayRange {
        switch self {
        case .yesterday: .last(1, daysBefore: now, calendar: calendar)
        case .lastSevenDays: .lastSevenDays(before: now, calendar: calendar)
        case .lastThirtyDays: .last(30, daysBefore: now, calendar: calendar)
        case .lastMonth: .lastMonth(before: now, calendar: calendar)
        }
    }

    /// What `range` is compared with: the same number of days just before it,
    /// or the month before for "Last month" (August for September).
    func comparison(for range: DayRange, calendar: Calendar = .current) -> DayRange {
        self == .lastMonth ? range.previousMonth(calendar: calendar) : range.previous(calendar: calendar)
    }

    /// When the supporter count is compared with: 7 days ago for "Last 7 days",
    /// a month ago for "Last month". Supporters is a count right now, not a total over days.
    func supporterBaselineDate(before now: Date, calendar: Calendar = .current) -> Date {
        let back: (Calendar.Component, Int) = switch self {
        case .yesterday: (.day, -1)
        case .lastSevenDays: (.day, -7)
        case .lastThirtyDays: (.day, -30)
        case .lastMonth: (.month, -1)
        }
        return calendar.date(byAdding: back.0, value: back.1, to: now) ?? now
    }

    /// The oldest saved supporter count that may stand in for the one at
    /// `supporterBaselineDate`. Counts are saved only when the app refreshes, so the
    /// right one may be missing; a much older one would overstate the change.
    func supporterBaselineEarliest(before now: Date, calendar: Calendar = .current) -> Date {
        let slack = switch self {
        case .yesterday: 1
        case .lastSevenDays: 3
        case .lastThirtyDays, .lastMonth: 7
        }
        let target = supporterBaselineDate(before: now, calendar: calendar)
        return calendar.date(byAdding: .day, value: -slack, to: target) ?? target
    }
}
