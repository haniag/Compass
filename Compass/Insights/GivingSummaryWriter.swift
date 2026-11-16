//
//  GivingSummaryWriter.swift
//  Compass
//
//  The two-sentence summary on Giving's "All pages" card, written by Apple Intelligence
//  on this device. Swift hands over the totals, the page names and the next step; the
//  model only words them, and GivingSummaryCheck throws away anything with an amount or
//  a page name that wasn't on the list.
//

import Foundation
import FoundationModels
import os

nonisolated enum GivingSummaryWriter {
    /// The worked example uses the same time words as the results, e.g. "in the last 30 days".
    static func instructions(for findings: GivingFindings) -> String {
        let during = findings.during
        let wordsToAvoid = findings.period?.wordsToAvoid ?? "Never say \"today\", \"yesterday\", \"week\" or \"month\"."
        return """
            You write a two-sentence summary of what a nonprofit's donation pages raised, \
            for the person who runs its fundraising. The app has already worked out the \
            numbers; you only put them into words.
            - First sentence: what the pages raised together and which page raised the most.
            - Second sentence: the next step you are given, in your own words.
            - Quote amounts with digits, exactly as they are written in the results. Never \
            calculate, round or estimate a new figure, and never give a page another page's amount.
            - Say "\(during)". \(wordsToAvoid)
            - Name a page only if the results name it; copy its name exactly, inside quotation marks.
            - Stay warm and encouraging.
            - Speak to the reader as "you" and "your supporters". Never write "we", "us", "our" or "let's".
            - Don't guess at causes and don't mention anything that isn't in the results.

            An example of the style only, about something the app doesn't track; never copy its words:
            All 3 event pages together: 420 tickets sold \(during).
            Top page: “Spring Gala”, with 300 tickets sold \(during).
            Next step: Look at what “Spring Gala” is doing well and try it on your other pages.
            Example summary: Your 3 event pages sold 420 tickets together \(during), and \
            “Spring Gala” led the way with 300. See what is working for “Spring Gala” and \
            borrow it for the others.
            """
    }

    /// The totals, the quiet pages and the next step: about 100 tokens.
    static func prompt(for findings: GivingFindings) -> String {
        "Results:\n" + findings.promptLines.joined(separator: "\n") + "\nNext step: \(findings.nextStep)"
    }

    /// Nil when the model fails or breaks the rules three times; Giving then shows the template.
    static func summary(from findings: GivingFindings) async -> String? {
        for attempt in 1...3 {
            guard !Task.isCancelled else { return nil }
            let session = LanguageModelSession(instructions: instructions(for: findings))
            let text: String
            do {
                let words = try await session.respond(
                    to: prompt(for: findings),
                    generating: GeneratedGivingSummary.self,
                    options: GenerationOptions(temperature: 0.3)
                ).content
                text = [words.overview, words.nextStep]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .joined(separator: " ")
            } catch {
                InsightWriter.log.error("Giving summary failed: \(String(describing: error), privacy: .public)")
                return nil
            }
            if GivingSummaryCheck.isSafe(text, findings: findings) { return text }
            InsightWriter.log.notice("Giving summary broke the rules (attempt \(attempt)): \(text, privacy: .public)")
        }
        return nil
    }
}

@Generable
nonisolated struct GeneratedGivingSummary {
    @Guide(description: "First sentence: what the pages raised together and which raised the most, quoting amounts exactly as written in the results")
    var overview: String
    @Guide(description: "Second sentence: the next step, in your own words, with no new numbers")
    var nextStep: String
}
