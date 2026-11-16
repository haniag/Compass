//
//  GivingSummaryTests.swift
//  CompassTests
//
//  Giving's "All pages" summary: what Swift picks out, the plain-words version, and
//  the check on what Apple Intelligence writes.
//

import Foundation
import Testing
@testable import Compass

private func page(_ id: Int, _ name: String, _ raised: Decimal) -> GivingStats.PageTotal {
    GivingStats.PageTotal(pageId: id, name: name, raised: raised)
}

private let busy = [page(1, "Fall Appeal 2026", 9_000), page(2, "Monthly giving", 3_345)]
private let withQuiet = busy + [page(3, "Spring Gala", 0)]

private func findings(_ pages: [GivingStats.PageTotal], days: Int? = 30) -> GivingFindings? {
    GivingFindings.make(pages: pages, days: days, currency: "USD")
}

struct GivingFindingsTests {
    @Test func nothingToSayWithOnePageOrNothingRaised() {
        #expect(findings([busy[0]]) == nil)
        #expect(findings([page(1, "A", 0), page(2, "B", 0)]) == nil)
    }

    @Test func findsTheTopAndTheQuietPages() throws {
        let found = try #require(findings(withQuiet))
        #expect(found.pageCount == 3)
        #expect(found.total == 12_345)
        #expect(found.top.name == "Fall Appeal 2026")
        #expect(found.quiet.map(\.name) == ["Spring Gala"])
        #expect(found.names == ["Fall Appeal 2026", "Spring Gala"])
    }

    @Test func noQuietPagesForTheWholeCampaign() throws {
        let found = try #require(findings(withQuiet, days: nil))
        #expect(found.quiet.isEmpty)
        #expect(found.during == "so far")
    }
}

struct GivingSummaryCheckTests {
    private let found = findings(busy)!
    private let quiet = findings(withQuiet)!

    @Test func theTemplatesPassTheirOwnCheck() throws {
        for found in [found, quiet, try #require(findings(withQuiet, days: nil)),
                      try #require(findings(busy + [page(3, "A", 0), page(4, "B", 0)], days: 7))] {
            #expect(GivingSummaryCheck.isSafe(found.template, findings: found), "\(found.template)")
        }
        #expect(found.template.contains("led by “Fall Appeal 2026” with \(found.formattedTop)"))
        #expect(quiet.template.contains("“Spring Gala”"))
    }

    @Test func allowsTheAppsAmountsAndPageNames() {
        let text = "Your 2 pages raised \(found.formattedTotal) together in the last 30 days, and "
            + "\"Fall Appeal 2026\" led the way with \(found.formattedTop). See what is working there and borrow it."
        #expect(GivingSummaryCheck.isSafe(text, findings: found))
    }

    @Test func rejectsAPageTheAppDidNotName() {
        // "Monthly giving" raised money but isn't the top or the quiet page.
        #expect(!GivingSummaryCheck.isSafe("“Monthly giving” helped raise \(found.formattedTotal).", findings: found))
        #expect(!GivingSummaryCheck.isSafe("“Fall Appeal” raised \(found.formattedTop).", findings: found))
    }

    @Test func rejectsAmountsTheModelWorkedOut() {
        // 12,345 − 9,000 = 3,345 is on screen in the list, but wasn't handed over.
        #expect(!GivingSummaryCheck.isSafe("Your other page raised $3,345 in the last 30 days.", findings: found))
        #expect(!GivingSummaryCheck.isSafe("“Fall Appeal 2026” raised 73% of the total.", findings: found))
    }

    @Test func rejectsGivingAPageTheWrongAmount() {
        #expect(!GivingSummaryCheck.isSafe("“Fall Appeal 2026” raised \(found.formattedTotal) in the last 30 days.", findings: found))
        #expect(!GivingSummaryCheck.isSafe("“Spring Gala” raised \(quiet.formattedTop) in the last 30 days.", findings: quiet))
        #expect(GivingSummaryCheck.isSafe("“Spring Gala” raised $0 in the last 30 days.", findings: quiet))
    }

    @Test func rejectsWrongPeriodsAndSpeakingAsTheOrganization() {
        #expect(!GivingSummaryCheck.isSafe("Your pages raised \(found.formattedTotal) this week.", findings: found))
        #expect(!GivingSummaryCheck.isSafe("We raised \(found.formattedTotal) in the last 30 days.", findings: found))
        // The whole campaign has no "last 30 days".
        let campaign = findings(busy, days: nil)!
        #expect(!GivingSummaryCheck.isSafe("Your pages raised \(found.formattedTotal) in the last 30 days.", findings: campaign))
    }

    @Test func thePromptNamesOnlyTheChosenPages() {
        let prompt = GivingSummaryWriter.prompt(for: quiet)
        #expect(prompt.contains("All 3 pages together: \(quiet.formattedTotal) raised in the last 30 days."))
        #expect(prompt.contains("No gifts in the last 30 days: “Spring Gala”."))
        #expect(!prompt.contains("Monthly giving"))
    }
}
