//
//  SupporterTrend.swift
//  Compass
//
//  Turns saved supporter counts into "change this week" and a weekly trend line.
//

import Foundation

nonisolated enum SupporterTrend {
    struct Point: Hashable, Sendable {
        let date: Date
        let count: Int
    }

    /// The newest count taken at or before `date`. `points` must be sorted oldest first.
    /// With `notBefore`, a count taken earlier than that doesn't count: a count from last
    /// week would make "change in the last day" a week's change.
    static func count(atOrBefore date: Date, notBefore earliest: Date? = nil, in points: [Point]) -> Int? {
        guard let point = points.last(where: { $0.date <= date }) else { return nil }
        if let earliest, point.date < earliest { return nil }
        return point.count
    }

    /// One point per week for up to `weeks` weeks back, ending with the newest count.
    /// Weeks with no saved count yet are skipped.
    static func weekly(_ points: [Point], weeks: Int, now: Date) -> [Point] {
        stride(from: weeks, through: 0, by: -1).compactMap { weeksAgo in
            let target = now.addingTimeInterval(-Double(weeksAgo) * 7 * 86_400)
            return count(atOrBefore: target, in: points).map { Point(date: target, count: $0) }
        }
    }
}
