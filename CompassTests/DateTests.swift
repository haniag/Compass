//
//  DateTests.swift
//  CompassTests
//
//  The two EN date formats, and the 7-day windows Pulse compares.
//

import Foundation
import Testing
@testable import Compass

struct ENDateFormatTests {
    @Test func parsesISODates() throws {
        let date = try #require(ENDateFormat.iso("2026-10-04"))
        #expect(TestDates.parts(date) == (2026, 10, 4))
        #expect(date == TestDates.date(2026, 10, 4))  // UTC midnight
    }

    @Test func isoIgnoresATrailingTime() throws {
        let date = try #require(ENDateFormat.iso("2026-10-04 18:30:00"))
        #expect(TestDates.parts(date) == (2026, 10, 4))
    }

    @Test(arguments: ["", "04/10/2026", "2026-13-01", "soon"])
    func isoRejectsOtherFormats(raw: String) {
        #expect(ENDateFormat.iso(raw) == nil)
    }

    @Test func isoRoundTrips() {
        #expect(ENDateFormat.isoString(from: TestDates.date(2026, 1, 9)) == "2026-01-09")
    }

    @Test func ddMMyyyyPutsTheDayFirstWithPadding() {
        let date = TestDates.date(2026, 3, 7, 15, 0)
        #expect(ENDateFormat.ddMMyyyyString(from: date, calendar: TestDates.utc) == "07/03/2026")
    }

    @Test func ddMMyyyyUsesTheGivenCalendarsDay() {
        // 23:30 UTC on Mar 7 is already Mar 8 in Tokyo.
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let date = TestDates.date(2026, 3, 7, 23, 30)
        #expect(ENDateFormat.ddMMyyyyString(from: date, calendar: tokyo) == "08/03/2026")
    }

    @Test func isoStringUsesTheGivenCalendarsDay() {
        // Midnight on Mar 8 in Tokyo is still Mar 7 in UTC; EN must be sent Mar 8.
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let tokyoMidnight = tokyo.date(from: DateComponents(year: 2026, month: 3, day: 8))!
        #expect(ENDateFormat.isoString(from: tokyoMidnight, calendar: tokyo) == "2026-03-08")
        #expect(ENDateFormat.isoString(from: tokyoMidnight) == "2026-03-07")  // the UTC version
    }

    @Test func parsesDDMMYYYYDayFirst() throws {
        let date = try #require(ENDateFormat.ddMMyyyy("06/10/2026", calendar: TestDates.utc))
        #expect(date == TestDates.date(2026, 10, 6))  // 6 October, not 10 June
    }

    @Test func ddMMyyyyIgnoresATrailingTime() throws {
        let date = try #require(ENDateFormat.ddMMyyyy("06/10/2026 00:00:00", calendar: TestDates.utc))
        #expect(TestDates.parts(date) == (2026, 10, 6))
    }

    @Test(arguments: ["", "2026-10-06", "31/02/2026", "06/10/26", "6/10"])
    func ddMMyyyyRejectsOtherFormats(raw: String) {
        #expect(ENDateFormat.ddMMyyyy(raw, calendar: TestDates.utc) == nil)
    }

    @Test func ddMMyyyyRoundTrips() {
        let day = TestDates.date(2026, 1, 9)
        let text = ENDateFormat.ddMMyyyyString(from: day, calendar: TestDates.utc)
        #expect(ENDateFormat.ddMMyyyy(text, calendar: TestDates.utc) == day)
    }
}

struct DayRangeTests {
    @Test func lastSevenDaysEndsYesterday() {
        let now = TestDates.date(2026, 9, 24, 13, 48)
        let range = DayRange.lastSevenDays(before: now, calendar: TestDates.utc)
        #expect(TestDates.parts(range.firstDay) == (2026, 9, 17))
        #expect(TestDates.parts(range.lastDay) == (2026, 9, 23))
    }

    @Test func previousIsTheSevenDaysBefore() {
        let now = TestDates.date(2026, 9, 24, 0, 5)
        let previous = DayRange.lastSevenDays(before: now, calendar: TestDates.utc).previous(calendar: TestDates.utc)
        #expect(TestDates.parts(previous.firstDay) == (2026, 9, 10))
        #expect(TestDates.parts(previous.lastDay) == (2026, 9, 16))
    }

    @Test func lastThirtyDaysAndTheThirtyBefore() {
        let now = TestDates.date(2026, 10, 7, 11, 0)
        let range = DayRange.last(30, daysBefore: now, calendar: TestDates.utc)
        #expect(TestDates.parts(range.firstDay) == (2026, 9, 7))
        #expect(TestDates.parts(range.lastDay) == (2026, 10, 6))
        let previous = range.previous(calendar: TestDates.utc)
        #expect(TestDates.parts(previous.firstDay) == (2026, 8, 8))
        #expect(TestDates.parts(previous.lastDay) == (2026, 9, 6))
    }

    @Test func containsWholeDaysOnly() {
        let range = DayRange.last(30, daysBefore: TestDates.date(2026, 10, 7, 11, 0), calendar: TestDates.utc)
        #expect(range.contains(TestDates.date(2026, 9, 7), calendar: TestDates.utc))
        #expect(range.contains(TestDates.date(2026, 10, 6, 23, 59), calendar: TestDates.utc))
        #expect(!range.contains(TestDates.date(2026, 10, 7), calendar: TestDates.utc))  // today isn't over yet
        #expect(!range.contains(TestDates.date(2026, 9, 6, 23, 59), calendar: TestDates.utc))
    }

    @Test func crossesMonthAndYearBoundaries() {
        let range = DayRange.lastSevenDays(before: TestDates.date(2026, 1, 3, 9), calendar: TestDates.utc)
        #expect(TestDates.parts(range.firstDay) == (2025, 12, 27))
        #expect(TestDates.parts(range.lastDay) == (2026, 1, 2))
    }
}
