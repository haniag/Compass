//
//  Fixtures.swift
//  CompassTests
//
//  Sample Engaging Networks replies in the real JSON shape, with made-up values.
//  Shapes follow the EN docs, including their quirks: every value is a string,
//  some services use UPPER_SNAKE or spaced column names, errors come back as HTTP 200.
//

import Foundation
@testable import Compass

enum Fixtures {
    static let supporterCount = """
    {"rows":[{"columns":[
      {"name":"clientId","value":"94","type":"xs:int"},
      {"name":"supporterCount","value":"22103","type":"xs:int"}
    ]}]}
    """

    /// What EN really sends for a bad token (IP and token made up).
    static let invalidToken = #"{"error":"Client IP [192.0.2.10] Invalid token specified [not-a-real-token]"}"#

    static let serviceError = #"{"error":"This service is not enabled for your account"}"#

    static let emptyRows = #"{"rows":[]}"#

    static let notJSON = "<EaData><EaRow></EaRow></EaData>"

    /// Numbers and null where strings are expected, plus an extra column.
    static let oddValues = """
    {"rows":[{"columns":[
      {"name":"sendCount","value":1234},
      {"name":"openRate","value":38.5},
      {"name":"broadcastName","value":null},
      {"name":"somethingNew","value":"x","format":""}
    ]}]}
    """

    static let activeJobs = """
    {"rows":[{"columns":[
      {"name":"JOB ID","value":"12447","type":"xs:int"},
      {"name":"JOB NAME","value":"User data export","type":"xs:string"},
      {"name":"PERCENT COMPLETE","value":"100","type":"xs:decimal"}
    ]}]}
    """

    static let campaignInfo = """
    {"rows":[
      {"columns":[{"name":"clientId","value":"94"},{"name":"campaignId","value":"1996"},
        {"name":"campaignStatus","value":"Live"},{"name":"campaignName","value":"Spring survey"},
        {"name":"campaignExportName","value":"Spring survey"},{"name":"description","value":""}]},
      {"columns":[{"name":"clientId","value":"94"},{"name":"campaignId","value":"1997"},
        {"name":"campaignStatus","value":"Deleted"},{"name":"campaignName","value":"Old test"}]},
      {"columns":[{"name":"clientId","value":"94"},{"name":"campaignId","value":"not a number"},
        {"name":"campaignName","value":"Broken row"}]}
    ]}
    """

    static let eventDetails = """
    {"rows":[
      {"columns":[{"name":"ID","value":"1"},{"name":"CAMPAIGN_ID","value":"6201"},
        {"name":"CAMPAIGN_PAGE_ID","value":"71201"},{"name":"PAGE_NAME","value":"Dinner 2026"},
        {"name":"PAGE_TITLE","value":"Harvest Dinner"},{"name":"EVENT_START_DATE","value":"2026-10-04"},
        {"name":"CITY","value":"Portland"},{"name":"ONLINE_EVENT","value":"N"}]},
      {"columns":[{"name":"ID","value":"2"},{"name":"CAMPAIGN_ID","value":"6203"},
        {"name":"PAGE_NAME","value":"Phone bank"},{"name":"PAGE_TITLE","value":""},
        {"name":"EVENT_START_DATE","value":"2026-12-01"},{"name":"CITY","value":""},{"name":"ONLINE_EVENT","value":"Y"}]}
    ]}
    """

    static let newJoins = """
    {"rows":[
      {"columns":[{"name":"Type","value":"total"},{"name":"Count","value":"386"}]},
      {"columns":[{"name":"Type","value":"import"},{"name":"Count","value":"0"}]},
      {"columns":[{"name":"Type","value":"netdonor"},{"name":"Count","value":"121"}]},
      {"columns":[{"name":"Type","value":"e-activist"},{"name":"Count","value":"265"}]}
    ]}
    """

    static let donorAmounts = """
    {"rows":[
      {"columns":[{"name":"Currency","value":"usd"},{"name":"Total","value":"23480.0"},{"name":"Average","value":"57.27"}]},
      {"columns":[{"name":"Currency","value":"EUR"},{"name":"Total","value":"91000.5"},{"name":"Average","value":"250.00"}]}
    ]}
    """

    static let broadcastStats = """
    {"rows":[
      {"columns":[{"name":"Type","value":"number of emails"},{"name":"Count","value":"3509.0"}]},
      {"columns":[{"name":"Type","value":"percentage open rate"},{"name":"Count","value":"7.41"}]},
      {"columns":[{"name":"Type","value":"Percentage Click Through"},{"name":"Count","value":"2.76"}]}
    ]}
    """

    /// Column names as the test account really sends them (note `softbounceCount`).
    static let broadcastInfo = """
    {"rows":[
      {"columns":[{"name":"clientId","value":"94"},{"name":"broadcastId","value":"16957"},
        {"name":"broadcastName","value":"Fall Appeal · Email 3"},{"name":"exportName","value":"Fall Appeal 3"},
        {"name":"broadcastDate","value":"06/10/2026"},{"name":"sendCount","value":"46210"},
        {"name":"openCount","value":"16636"},{"name":"clickCount","value":"1479"},{"name":"compCount","value":"312"},
        {"name":"hardBounceCount","value":"40"},{"name":"softbounceCount","value":"95"},
        {"name":"unsubscribeCount","value":"328"},{"name":"feedbackCount","value":"2"}]},
      {"columns":[{"name":"broadcastId","value":"16926"},{"name":"broadcastName","value":""},
        {"name":"exportName","value":"Newsletter"},{"name":"broadcastDate","value":"30/09/2026"},
        {"name":"sendCount","value":"1,200"}]},
      {"columns":[{"name":"broadcastId","value":"16900"},{"name":"broadcastName","value":"No date"},
        {"name":"broadcastDate","value":""},{"name":"sendCount","value":"10"}]}
    ]}
    """

    /// Real column names; one-time and recurring gifts in USD, nothing in other currencies.
    static let pageGiving = """
    {"rows":[{"columns":[
      {"name":"ID","value":"5101"},{"name":"NAME","value":"Fall Appeal 2026"},
      {"name":"TOTAL_NUMBER","value":"2278"},{"name":"TOTAL_AMOUNT_USD","value":"184250.00"},
      {"name":"TOTAL_AMOUNT_GBP","value":"0.00"},{"name":"TOTAL_AMOUNT_EUR","value":"0.00"},
      {"name":"TOTAL_AMOUNT_CAD","value":"0.00"},{"name":"TOTAL_AMOUNT_AUD","value":"0.00"},
      {"name":"TOTAL_NUMBER_SINGLE","value":"1960"},{"name":"TOTAL_AMOUNT_SINGLE_USD","value":"142900.00"},
      {"name":"TOTAL_AMOUNT_SINGLE_GBP","value":"0.00"},
      {"name":"TOTAL_NUMBER_RECURRING","value":"318"},{"name":"TOTAL_AMOUNT_RECURRING_USD","value":"41350.00"},
      {"name":"TOTAL_AMOUNT_RECURRING_GBP","value":"0.00"}
    ]}]}
    """

    /// Invented donors; the comments column must never be read.
    static let rollCall = """
    {"rows":[
      {"columns":[{"name":"name","value":"Maria Garcia Lopez"},{"name":"country","value":"CA"},{"name":"city","value":"Toronto"},
        {"name":"currency","value":"usd"},{"name":"amount","value":"50.00"},{"name":"additionalComments","value":"In memory of my dad"}]},
      {"columns":[{"name":"name","value":"anonymous"},{"name":"city","value":""},{"name":"currency","value":"USD"},{"name":"amount","value":"25"}]},
      {"columns":[{"name":"name","value":"Cher"},{"name":"amount","value":"10"}]},
      {"columns":[{"name":"name","value":"No amount"},{"name":"amount","value":""}]}
    ]}
    """

    /// The part of a live page that matters, in the real shape (IDs and names made up).
    static let livePage = """
    <link rel="canonical" href="https://test.engagingnetworks.app/page/71101/donate/1?locale=en-US"/>
    <script nonce='x'>var pageJson = {"clientId":94,"campaignPageId":71101,"campaignId":5101,"pageNumber":1,"pageCount":2,\
    "pageName":"Fall Appeal 2026 ","pageType":"donation","locale":"en-US","giftProcess":false,\
    "tickets":[{"name":"x","quantity":0,"price":0}]};</script>
    <script nonce='x' src='/page/71101/pagedata.js?locale=en-US'></script>
    """

    static let inactivePage = "<html><body><p>This page is currently inactive</p></body></html>"

    static func data(_ json: String) -> Data { Data(json.utf8) }

    static func rows(_ json: String) throws -> [ENRow] {
        try ENResponse.rows(from: data(json))
    }
}

/// Dates for tests, pinned to UTC so results don't depend on the Mac's time zone.
enum TestDates {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    static func parts(_ date: Date) -> (year: Int, month: Int, day: Int) {
        let parts = utc.dateComponents([.year, .month, .day], from: date)
        return (parts.year!, parts.month!, parts.day!)
    }
}
