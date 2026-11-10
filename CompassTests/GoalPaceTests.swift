//
//  GoalPaceTests.swift
//  CompassTests
//
//  Progress toward a goal and whether recent giving keeps pace.
//

import Foundation
import Testing
@testable import Compass

struct GoalPaceTests {
    private let now = TestDates.date(2026, 11, 10, 9)

    private func pace(raised: Decimal, recent: Decimal = 0, deadline: Date?) -> GoalPace {
        GoalPace(goal: 10_000, raised: raised, recentRaised: recent, deadline: deadline, now: now, calendar: TestDates.utc)
    }

    @Test func progressTowardTheGoal() {
        let pace = pace(raised: 4_250, deadline: nil)
        #expect(pace.percent == 42)
        #expect(pace.fraction == 0.425)
        #expect(pace.remaining == 5_750)
        #expect(pace.outlook == .noDeadline)
        #expect(pace.daysLeft == nil)
    }

    @Test func reachedOnceRaisedMeetsTheGoal() {
        let pace = pace(raised: 12_000, deadline: TestDates.date(2026, 11, 20))
        #expect(pace.outlook == .reached)
        #expect(pace.fraction == 1)
        #expect(pace.percent == 120)
        #expect(pace.remaining == 0)
    }

    @Test func countsTodayAndTheDeadlineDay() {
        #expect(pace(raised: 0, deadline: TestDates.date(2026, 11, 19)).daysLeft == 10)
        #expect(pace(raised: 0, deadline: TestDates.date(2026, 11, 10, 23)).daysLeft == 1)
    }

    @Test func onTrackWhenRecentGivingCoversWhatIsNeeded() {
        // $6,000 to go over 10 days = $600 a day; the last 7 days brought $4,900 = $700 a day.
        let pace = pace(raised: 4_000, recent: 4_900, deadline: TestDates.date(2026, 11, 19))
        #expect(pace.outlook == .onTrack(neededPerDay: 600, recentPerDay: 700))
    }

    @Test func behindWhenRecentGivingFallsShort() {
        let pace = pace(raised: 4_000, recent: 2_100, deadline: TestDates.date(2026, 11, 19))
        #expect(pace.outlook == .behind(neededPerDay: 600, recentPerDay: 300))
    }

    @Test func endedWhenTheDeadlinePassedShortOfTheGoal() {
        let pace = pace(raised: 4_000, recent: 9_000, deadline: TestDates.date(2026, 11, 9))
        #expect(pace.outlook == .ended)
        #expect(pace.daysLeft == 0)
    }
}
