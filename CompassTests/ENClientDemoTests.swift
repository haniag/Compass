//
//  ENClientDemoTests.swift
//  CompassTests
//
//  ENClient end to end, using demo mode (token "1") so no network is touched.
//

import Foundation
import Testing
@testable import Compass

struct ENClientDemoTests {
    private let client = ENClient(credentials: ENCredentials(region: .test, token: ENDemoData.token))

    @Test func supporterCount() async throws {
        #expect(try await client.supporterCount() == ENDemoData.supporterCount)
    }

    @Test func campaignsByID() async throws {
        let all = try await client.campaigns()
        #expect(all.count > 5)
        let one = try await client.campaigns(ids: [5101])
        #expect(one.map(\.name) == ["Fall Appeal 2026"])
    }

    @Test func upcomingEvents() async throws {
        let events = try await client.upcomingEvents()
        #expect(events.count == 3)
        #expect(events.allSatisfy { $0.startDate != nil })
    }

    @Test func lastSevenDaysReports() async throws {
        let range = DayRange.lastSevenDays(before: .now)
        #expect(try await client.newJoins(from: range.firstDay, through: range.lastDay) == 386)

        let giving = try await client.donationAmounts(from: range.firstDay, through: range.lastDay)
        #expect(giving.first?.currency == "USD")
        #expect(giving.first?.total == 23_480)

        let email = try await client.broadcastStats(from: range.firstDay, through: range.lastDay)
        #expect(email.emailsSent == 41_200)
        #expect(email.openRate == Decimal(string: "38.2"))
    }

    @Test func theSevenDaysBeforeGetDifferentNumbers() async throws {
        let previous = DayRange.lastSevenDays(before: .now).previous()
        #expect(try await client.newJoins(from: previous.firstDay, through: previous.lastDay) == 342)
    }

    @Test func broadcastsStopAtTheFirstDay() async throws {
        let firstDay = Calendar.current.date(byAdding: .day, value: -90, to: Calendar.current.startOfDay(for: .now))!
        let sends = try await client.broadcasts(since: firstDay)
        #expect(sends.count == 24)  // the 25th demo send is 96 days old
        #expect(sends.allSatisfy { $0.sentOn >= firstDay })
        #expect(sends.first?.name == "Fall Appeal · Email 3")
        #expect(sends.first?.sent == 46_210)
    }

    @Test func pageDetailsByLink() async throws {
        let page = try await client.pageDetails(pageId: 71101)
        #expect(page.campaignId == 5101)
        await #expect(throws: ENError.pageUnavailable) {
            try await client.pageDetails(pageId: 999)
        }
    }

    @Test func pageGivingByWindow() async throws {
        let range = DayRange.last(7, daysBefore: .now)
        let week = try #require(try await client.pageGiving(pageId: 71101, from: range.firstDay, through: range.lastDay))
        #expect(week.raisedSingle["USD"] == 13_650)  // 7 × 1,950
        let before = try #require(try await client.pageGiving(pageId: 71101, from: range.previous().firstDay,
                                                              through: range.previous().lastDay))
        #expect(before.raised["USD"]! < week.raised["USD"]!)
        #expect(try await client.pageGiving(pageId: 999, from: range.firstDay, through: range.lastDay) == nil)
    }

    @Test func recentGiftsForACampaign() async throws {
        #expect(try await client.recentGifts(campaignId: 5101).count == 7)
        #expect(try await client.recentGifts(campaignId: 5103).isEmpty)
    }

    @Test func demoIsOnlyTokenOne() {
        #expect(ENCredentials(region: .test, token: "1").isDemo)
        #expect(!ENCredentials(region: .test, token: "11").isDemo)
        #expect(!ENCredentials(region: .us, token: "a-real-looking-token").isDemo)
    }
}
