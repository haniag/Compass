//
//  GoalPace.swift
//  Compass
//
//  How far a donation page is toward the goal the user set, and whether recent
//  giving is fast enough to get there by the deadline. EN has no goals or
//  deadlines; both are entered in the app. Pure functions; no wording here.
//

import Foundation

nonisolated struct GoalPace: Hashable, Sendable {
    /// Recent giving is measured over this many complete days.
    static let recentDays = 7

    enum Outlook: Hashable, Sendable {
        /// The goal is met.
        case reached
        /// No deadline was set, so there's no pace to judge.
        case noDeadline
        /// The deadline passed before the goal was met.
        case ended
        /// Recent giving is at or above what's needed each day.
        case onTrack(neededPerDay: Decimal, recentPerDay: Decimal)
        /// Recent giving is below what's needed each day.
        case behind(neededPerDay: Decimal, recentPerDay: Decimal)
    }

    let goal: Decimal
    let raised: Decimal
    /// Days left to give, today and the deadline day included. Nil without a deadline.
    let daysLeft: Int?
    let outlook: Outlook

    /// `raised` is the page's total so far; `recentRaised` what came in over the last
    /// `recentDays` complete days.
    init(goal: Decimal, raised: Decimal, recentRaised: Decimal, deadline: Date?,
         now: Date, calendar: Calendar = .current) {
        self.goal = goal
        self.raised = raised

        let today = calendar.startOfDay(for: now)
        let left = deadline.map { deadline in
            (calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: deadline)).day ?? 0) + 1
        }
        daysLeft = left.map { max($0, 0) }

        if raised >= goal {
            outlook = .reached
        } else if let left {
            if left <= 0 {
                outlook = .ended
            } else {
                let needed = (goal - raised) / Decimal(left)
                let recent = recentRaised / Decimal(Self.recentDays)
                outlook = recent >= needed ? .onTrack(neededPerDay: needed, recentPerDay: recent)
                                           : .behind(neededPerDay: needed, recentPerDay: recent)
            }
        } else {
            outlook = .noDeadline
        }
    }

    /// Still to raise; 0 once the goal is met.
    var remaining: Decimal { max(goal - raised, 0) }

    /// How full the thermometer is, 0…1.
    var fraction: Double {
        guard goal > 0 else { return 0 }
        return min(max(NSDecimalNumber(decimal: raised / goal).doubleValue, 0), 1)
    }

    /// Whole percent of the goal raised; can pass 100.
    var percent: Int {
        guard goal > 0 else { return 0 }
        return Int(NSDecimalNumber(decimal: raised / goal * 100).doubleValue.rounded(.down))
    }
}
