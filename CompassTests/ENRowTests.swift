//
//  ENRowTests.swift
//  CompassTests
//
//  Reading EN's flat row/column replies.
//

import Foundation
import Testing
@testable import Compass

struct ENRowTests {
    @Test func readsAColumnByName() throws {
        let rows = try Fixtures.rows(Fixtures.supporterCount)
        #expect(rows.count == 1)
        #expect(rows[0].int("supporterCount") == 22103)
        #expect(rows[0].string("clientId") == "94")
    }

    @Test func columnNamesIgnoreCaseUnderscoresAndSpaces() throws {
        let event = try Fixtures.rows(Fixtures.eventDetails)[0]
        #expect(event.int("campaignId") == 6201)
        #expect(event.int("CAMPAIGN_ID") == 6201)
        #expect(event.string("page title") == "Harvest Dinner")

        let job = try Fixtures.rows(Fixtures.activeJobs)[0]
        #expect(job.int("jobId") == 12447)
        #expect(job.string("JOB_NAME") == "User data export")
    }

    @Test func missingOrEmptyColumnsAreNil() throws {
        let row = try Fixtures.rows(Fixtures.eventDetails)[1]
        #expect(row["noSuchColumn"] == nil)
        #expect(row.string("PAGE_TITLE") == nil)  // present but ""
        #expect(row.int("CAMPAIGN_PAGE_ID") == nil)  // absent
    }

    @Test func toleratesNumbersNullsAndExtraColumns() throws {
        let row = try Fixtures.rows(Fixtures.oddValues)[0]
        #expect(row.int("sendCount") == 1234)
        #expect(row.decimal("openRate") == Decimal(string: "38.5"))
        #expect(row.string("broadcastName") == nil)
        #expect(row.string("somethingNew") == "x")
    }

    @Test(arguments: [
        ("1234", 1234),
        ("1,234", 1234),
        (" 29527.0 ", 29527),
        ("0", 0),
    ])
    func parsesWholeNumbers(raw: String, expected: Int) {
        #expect(ENRow(["n": raw]).int("n") == expected)
    }

    @Test(arguments: ["12.5", "abc", ""])
    func rejectsValuesThatArentWholeNumbers(raw: String) {
        #expect(ENRow(["n": raw]).int("n") == nil)
    }

    @Test func parsesDecimalsExactly() {
        let row = ENRow(["total": "2384490.0", "average": "357.44", "big": "1,234.56"])
        #expect(row.decimal("total") == Decimal(2_384_490))
        #expect(row.decimal("average") == Decimal(string: "357.44"))
        #expect(row.decimal("big") == Decimal(string: "1234.56"))
        #expect(row.decimal("missing") == nil)
    }

    @Test func typeCountsAreKeyedByLowercasedType() throws {
        let counts = try Fixtures.rows(Fixtures.broadcastStats).typeCounts
        #expect(counts["number of emails"] == Decimal(3509))
        #expect(counts["percentage open rate"] == Decimal(string: "7.41"))
        #expect(counts["percentage click through"] == Decimal(string: "2.76"))
    }

    // MARK: Errors

    @Test func badTokenBecomesInvalidToken() {
        #expect(throws: ENError.invalidToken) {
            try Fixtures.rows(Fixtures.invalidToken)
        }
    }

    @Test func otherEnErrorsBecomeServiceError() {
        #expect(throws: ENError.serviceError) {
            try Fixtures.rows(Fixtures.serviceError)
        }
    }

    @Test func nonJSONIsUnexpected() {
        #expect(throws: ENError.unexpectedResponse) {
            try Fixtures.rows(Fixtures.notJSON)
        }
        #expect(throws: ENError.unexpectedResponse) {
            try Fixtures.rows("{}")
        }
    }

    @Test func emptyRowsAreFine() throws {
        #expect(try Fixtures.rows(Fixtures.emptyRows).isEmpty)
    }

    @Test func credentialsNeverPrintTheToken() {
        let credentials = ENCredentials(region: .test, token: "secret-token-value")
        #expect(!"\(credentials)".contains("secret-token-value"))
        #expect(!String(reflecting: credentials).contains("secret-token-value"))
    }
}
