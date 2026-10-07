//
//  ENModelTests.swift
//  CompassTests
//
//  Turning rows into campaigns, events, gifts and email stats.
//

import Foundation
import Testing
@testable import Compass

struct ENModelTests {
    @Test func campaignsSkipRowsWithoutAnID() throws {
        let campaigns = try Fixtures.rows(Fixtures.campaignInfo).compactMap(ENCampaign.init(row:))
        #expect(campaigns.map(\.id) == [1996, 1997])
        #expect(campaigns[0].name == "Spring survey")
        #expect(campaigns[0].isLive)
        #expect(!campaigns[0].isRemoved)
        #expect(campaigns[1].isRemoved)
    }

    @Test(arguments: [
        ("Live", "Live"),
        ("New", "Not live yet"),
        ("Closed", "Closed"),
        ("", "Page"),
        ("Paused", "Paused"),
    ])
    func campaignStatusInPlainWords(status: String, label: String) {
        #expect(ENCampaign(id: 1, name: "x", status: status).statusLabel == label)
    }

    @Test(arguments: ["Deleted", "deleted", "Blocked"])
    func deletedAndBlockedAreRemoved(status: String) {
        #expect(ENCampaign(id: 1, name: "x", status: status).isRemoved)
    }

    @Test func eventsReadTitleDateAndPlace() throws {
        let events = try Fixtures.rows(Fixtures.eventDetails).compactMap(ENEvent.init(row:))
        #expect(events.count == 2)

        let dinner = events[0]
        #expect(dinner.campaignId == 6201)
        #expect(dinner.pageId == 71201)
        #expect(dinner.name == "Harvest Dinner")
        #expect(dinner.city == "Portland")
        #expect(!dinner.isOnline)
        let start = try #require(dinner.startDate)
        #expect(TestDates.parts(start) == (2026, 10, 4))
        #expect(dinner.summary.hasSuffix("· Portland"))

        let phoneBank = events[1]
        #expect(phoneBank.name == "Phone bank")  // falls back to PAGE_NAME when the title is empty
        #expect(phoneBank.isOnline)
        #expect(phoneBank.city == nil)
        #expect(phoneBank.summary.hasSuffix("· Online"))
    }

    @Test func donationAmountsPerCurrency() throws {
        let amounts = try Fixtures.rows(Fixtures.donorAmounts).compactMap(ENDonationAmount.init(row:))
        #expect(amounts.count == 2)
        #expect(amounts[0].currency == "USD")  // uppercased
        #expect(amounts[0].total == Decimal(23480))
        #expect(amounts[0].average == Decimal(string: "57.27"))
        #expect(amounts[1].currency == "EUR")
    }

    @Test func pageGivingSplitsOneTimeAndRecurring() throws {
        let giving = try #require(try Fixtures.rows(Fixtures.pageGiving).compactMap(ENPageGiving.init(row:)).first)
        #expect(giving.campaignId == 5101)
        #expect(giving.gifts == 2_278)
        #expect(giving.singleGifts == 1_960)
        #expect(giving.recurringGifts == 318)
        #expect(giving.raised["USD"] == 184_250)
        #expect(giving.raisedSingle["USD"] == 142_900)
        #expect(giving.raisedRecurring["USD"] == 41_350)
        #expect(giving.raised["GBP"] == 0)
        #expect(giving.raisedRecurring["EUR"] == nil)  // column missing
    }

    @Test func recentGiftsKeepNamesShort() throws {
        let gifts = try Fixtures.rows(Fixtures.rollCall).compactMap(ENRecentGift.init(row:))
        #expect(gifts.count == 3)  // the row with no amount is skipped
        #expect(gifts[0].shortName == "Maria L.")
        #expect(gifts[0].city == "Toronto")
        #expect(gifts[0].currency == "USD")
        #expect(gifts[0].amount == 50)
        #expect(gifts[1].shortName == "Anonymous")
        #expect(gifts[1].city == nil)
        #expect(gifts[2].shortName == "Cher")
        #expect(gifts[2].currency == AccountSettings.reportingCurrency)
    }

    @Test func pageDetailsFromALivePage() throws {
        let page = try #require(ENPageDetails(html: Fixtures.livePage))
        #expect(page.pageId == 71101)
        #expect(page.campaignId == 5101)
        #expect(page.name == "Fall Appeal 2026")  // trimmed
        #expect(page.type == "donation")
        #expect(page.takesGifts)
    }

    @Test func inactivePagesHaveNoDetails() {
        #expect(ENPageDetails(html: Fixtures.inactivePage) == nil)
        #expect(ENPageDetails(html: "var pageJson = {not json};</script>") == nil)
    }

    @Test func petitionsDontTakeGifts() {
        let petition = ENPageDetails(pageId: 1, campaignId: 2, name: "x", type: "advocacypetition")
        #expect(!petition.takesGifts)
        #expect(petition.typeLabel == "petition")
    }

    @Test(arguments: [
        ("https://test.engagingnetworks.app/page/17697/donate/1", 17697),
        ("https://act.example.org/page/71101/donate/1?locale=en-US", 71101),
        ("  test.engagingnetworks.app/page/42  ", 42),
        ("71101", 71101),
    ])
    func pageIDFromALink(text: String, pageId: Int) {
        #expect(ENPageLink.pageId(from: text) == pageId)
    }

    @Test(arguments: ["", "https://example.org/donate", "page 12", "-5", "/page/abc"])
    func noPageIDInOtherText(text: String) {
        #expect(ENPageLink.pageId(from: text) == nil)
    }

    @Test func broadcastsReadCountsAndDayFirstDates() throws {
        let sends = try Fixtures.rows(Fixtures.broadcastInfo).compactMap { ENBroadcast(row: $0, calendar: TestDates.utc) }
        #expect(sends.map(\.id) == [16957, 16926])  // the row with no date is skipped

        let appeal = sends[0]
        #expect(appeal.name == "Fall Appeal · Email 3")
        #expect(appeal.sentOn == TestDates.date(2026, 10, 6))
        #expect(appeal.sent == 46_210)
        #expect(appeal.opens == 16_636)
        #expect(appeal.clicks == 1_479)
        #expect(appeal.unsubscribes == 328)

        let newsletter = sends[1]
        #expect(newsletter.name == "Newsletter")  // falls back to exportName when the name is empty
        #expect(newsletter.sent == 1_200)         // "1,200"
        #expect(newsletter.opens == 0)            // missing columns count as 0
    }
}
