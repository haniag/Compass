//
//  EmailSummaryWriter.swift
//  Compass
//
//  The Email tab's two-sentence summary, written by Apple Intelligence on this device.
//  Swift hands over the rates, the one thing worth pointing out and the next step; the
//  model only words them, and EmailSummaryCheck throws away anything with a figure or
//  an email name that wasn't on the list.
//

import Foundation
import FoundationModels
import os

nonisolated enum EmailSummaryWriter {
    static var instructions: String {
        let period = EmailFindings.period
        let during = period.during
        return """
            You write a two-sentence summary of a nonprofit's email results for the person \
            who sends its emails. The app has already worked out the numbers; you only put \
            them into words.
            - First sentence: how the emails did, quoting one or two of the rates.
            - Second sentence: the next step you are given, in your own words.
            - Quote figures with digits, exactly as they are written in the results. Never \
            calculate, round or estimate a new figure.
            - Say whether each rate went up or down exactly as the results say; never swap them.
            - Say "\(during)". \(period.wordsToAvoid)
            - Name an email only if the results name it; copy its name exactly, inside quotation marks.
            - Be honest about anything that went down, and stay warm and encouraging.
            - Speak to the reader as "you" and "your supporters". Never write "we", "us", "our" or "let's".
            - Don't guess at causes and don't mention anything that isn't in the results.

            An example of the style only, about rates the app doesn't track; never copy its words:
            Replies: 2.0% \(during), down 0.6 pts from \(period.before). This needs attention.
            Forwards: 1.5% \(during), up 0.3 pts from \(period.before). This is good news.
            Best email: “Spring update”, with a 5.0% click rate.
            Next step: See what worked in “Spring update”, your most-clicked email, and try it again.
            Example summary: Replies slipped 0.6 pts to 2.0% \(during), while forwards edged \
            up 0.3 pts to 1.5%. Take a look at what made “Spring update” land so well and bring \
            that into your next email.
            """
    }

    /// The rates, the supporting line and the next step: about 150 tokens.
    static func prompt(for findings: EmailFindings) -> String {
        var prompt = "Results:\n" + findings.promptLines.joined(separator: "\n")
        if let step = findings.support?.nextStep {
            prompt += "\nNext step: \(step)"
        }
        return prompt
    }

    /// Nil when the model fails or breaks the rules three times; Email then shows the template.
    static func summary(from findings: EmailFindings) async -> String? {
        for attempt in 1...3 {
            guard !Task.isCancelled else { return nil }
            let session = LanguageModelSession(instructions: instructions)
            let text: String
            do {
                let words = try await session.respond(
                    to: prompt(for: findings),
                    generating: GeneratedEmailSummary.self,
                    options: GenerationOptions(temperature: 0.3)
                ).content
                text = [words.overview, words.nextStep]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .joined(separator: " ")
            } catch {
                InsightWriter.log.error("Email summary failed: \(String(describing: error), privacy: .public)")
                return nil
            }
            if EmailSummaryCheck.isSafe(text, findings: findings) { return text }
            InsightWriter.log.notice("Email summary broke the rules (attempt \(attempt)): \(text, privacy: .public)")
        }
        return nil
    }
}

@Generable
nonisolated struct GeneratedEmailSummary {
    @Guide(description: "First sentence: how the emails did, quoting one or two rates exactly as written in the results")
    var overview: String
    @Guide(description: "Second sentence: the next step, in your own words, with no new numbers")
    var nextStep: String
}
