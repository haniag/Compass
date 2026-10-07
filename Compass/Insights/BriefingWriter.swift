//
//  BriefingWriter.swift
//  Compass
//
//  Pulse's two-sentence briefing for the Executive Director, written by Apple
//  Intelligence on this device. Swift hands over figures it already worked out;
//  the model may quote them but never work out new ones, and BriefingCheck
//  (through FigureCheck) throws away any briefing with a figure that isn't on the list.
//

import Foundation
import FoundationModels
import os

nonisolated enum BriefingWriter {
    static let instructions = """
        You are a data analyst for a nonprofit. Summarize these metrics from the last 7 days \
        into a two-sentence encouraging briefing for the Executive Director.
        - Quote figures with digits, exactly as they are written in the metrics. Never calculate, \
        round or estimate a new figure.
        - Say "in the last 7 days". Never say "today", "yesterday" or "week".
        - Be honest about anything that went down, and stay warm and encouraging.
        - Speak to the reader as "you" and "your supporters". Never write "we", "us", "our" or "let's".
        - Don't guess at causes and don't mention anything that isn't in the metrics.

        Example metrics:
        New joins: 42 in the last 7 days, 30 in the 7 days before (up 40%).
        Raised: $15,400 in the last 7 days, $14,000 in the 7 days before (up 10%).
        Email opens: 31.0% in the last 7 days, 33.5% in the 7 days before (down 2.5 pts).
        Example briefing: Great news: 42 people joined in the last 7 days, up 40%, and you raised \
        $15,400, up 10%. Email opens slipped 2.5 pts to 31.0%, so your next subject line is a good \
        place to win readers back.
        """

    /// "Supporters: 539,479 now, 539,470 7 days ago (up 9)." One line per figure, ~150 tokens in all.
    static func prompt(for facts: [Fact]) -> String {
        "Metrics:\n" + facts.map(\.summaryLine).joined(separator: "\n")
    }

    /// Nil when the model fails or breaks the rules three times; Pulse then shows its template insight.
    static func briefing(from facts: [Fact]) async -> String? {
        guard !facts.isEmpty else { return nil }
        for attempt in 1...3 {
            guard !Task.isCancelled else { return nil }
            let session = LanguageModelSession(instructions: instructions)
            let text: String
            do {
                let words = try await session.respond(
                    to: prompt(for: facts),
                    generating: GeneratedBriefing.self,
                    options: GenerationOptions(temperature: 0.3)
                ).content
                text = [words.highlight, words.followUp]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .joined(separator: " ")
            } catch {
                InsightWriter.log.error("Briefing failed: \(String(describing: error), privacy: .public)")
                return nil
            }
            if BriefingCheck.isSafe(text, facts: facts) { return text }
            InsightWriter.log.notice("Briefing broke the rules (attempt \(attempt)): \(text, privacy: .public)")
        }
        return nil
    }
}

@Generable
nonisolated struct GeneratedBriefing {
    @Guide(description: "First sentence: the best news, quoting its figures exactly as written in the metrics")
    var highlight: String
    @Guide(description: "Second sentence: what went down, said kindly, quoting its figures exactly as written; or another bright spot if nothing went down")
    var followUp: String
}

/// The briefing may quote figures, but only ones Swift worked out.
nonisolated enum BriefingCheck {
    /// No more than this many words: about two sentences.
    static let maxWords = 70

    static func isSafe(_ text: String, facts: [Fact]) -> Bool {
        guard !text.isEmpty, text.split(separator: " ").count <= maxWords else { return false }
        return FigureCheck.quotesOnlyFigures(of: facts, in: text)
    }
}
