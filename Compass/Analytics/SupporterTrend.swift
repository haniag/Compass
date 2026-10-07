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
    static func count(atOrBefore date: Date, in points: [Point]) -> Int? {
        points.last { $0.date <= date }?.count
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
