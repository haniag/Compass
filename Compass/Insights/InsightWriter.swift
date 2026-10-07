//
//  InsightWriter.swift
//  Compass
//
//  Writes insights with Apple Intelligence (Foundation Models), on this device only.
//  Swift chooses the facts; the model puts them into words. Everything it returns
//  goes through InsightCheck before it's shown.
//

import Foundation
import FoundationModels
import os

nonisolated enum InsightWriter {
    /// Why a draft failed or was rejected. Never logs figures or personal data.
    static let log = Logger(subsystem: "com.fursa.Compass", category: "AI")

    enum Status: Equatable, Sendable {
        case available
        /// The device supports it but Apple Intelligence is off in Settings.
        case turnedOff
        /// Not supported here, still downloading, or not in this language.
        case unavailable
    }

    static var status: Status {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale() ? .available : .unavailable
        case .unavailable(.appleIntelligenceNotEnabled):
            return .turnedOff
        case .unavailable:
            return .unavailable
        }
    }

    static let digestInstructions = """
        You write one insight for a weekly digest read by the staff of a nonprofit: \
        fundraisers, email managers and campaigners. The app has already worked out \
        the numbers; you only put one fact into words.
        - Speak to the reader as "you" and "your supporters". Never write "we", "us", "our" or "let's".
        - Use plain, warm, specific words: supporters, gifts, appeals, actions.
        - Never write digits, amounts or percentages. The app shows the figures next to your words.
        - Say only what the fact shows: whether it went up or down, and why that matters. \
        Don't praise or mention anything else (appeals, emails, campaigns), don't guess at causes, \
        and don't compare with other organizations.
        - Don't mention dates or time periods at all, and don't restate amounts in words \
        (no "half" or "twice"); the app shows the figures and dates next to your words.
        - Keep the next step out of the explanation; it goes only in the suggested action.
        """

    /// Up to one draft per fact InsightRules picked, in the same order. Each fact gets its own
    /// short request: the on-device model is much more reliable with one thing at a time.
    /// The fact ID and severity come from Swift; the model writes only the words.
    static func drafts(about highlights: [Fact]) async throws -> [InsightDraft] {
        var drafts: [InsightDraft] = []
        for fact in highlights {
            // One retry if the words break the copy rules; after that the template is used.
            for attempt in 1...2 {
                try Task.checkCancellation()
                let draft: InsightDraft
                do {
                    draft = try await self.draft(about: fact)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    // The model refused or failed on this fact (e.g. a safety check).
                    // Skip it; its template insight fills the gap.
                    log.error("Draft for \(fact.id, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                    break
                }
                let passed = InsightCheck.validated([draft], facts: [fact]).count == 1
                if !passed {
                    log.notice("Draft for \(fact.id, privacy: .public) broke the copy rules (attempt \(attempt)): \(draft.title, privacy: .public) | \(draft.explanation, privacy: .public) | \(draft.suggestedAction ?? "", privacy: .public)")
                }
                if passed || attempt == 2 {
                    drafts.append(draft)
                    break
                }
            }
        }
        return drafts
    }

    private static func draft(about fact: Fact) async throws -> InsightDraft {
        let session = LanguageModelSession(instructions: digestInstructions)
        let words = try await session.respond(
            to: prompt(for: fact),
            generating: GeneratedInsight.self,
            options: GenerationOptions(temperature: 0.5)
        ).content
        return InsightDraft(
            title: words.title,
            severity: TemplateInsights.severity(for: fact),
            factIDs: [fact.id],
            explanation: words.explanation,
            suggestedAction: words.suggestedAction
        )
    }

    /// The fact, whether it's good, and the template's next step as a starting idea.
    static func prompt(for fact: Fact) -> String {
        var prompt = "Fact: \(fact.summaryLine)\(verdict(fact))"
        if let idea = TemplateInsights.suggestedAction(for: fact) {
            prompt += "\nA good next step, to put in your own words: \(idea)"
        }
        return prompt
    }

    private static func verdict(_ fact: Fact) -> String {
        switch fact.change?.isGood {
        case true?: " This is good news."
        case false?: " This needs attention."
        case nil: ""
        }
    }

    /// "id: newJoins.lastSevenDays. New joins: 386 in the last 7 days, … This is good news."
    static func promptLine(_ fact: Fact) -> String {
        "id: \(fact.id). \(fact.summaryLine)\(verdict(fact))"
    }
}

// MARK: - Ask about your numbers

/// A conversation about the numbers. Follow-up questions see earlier answers.
final class NumbersChat {
    static let instructions = """
        You answer questions from nonprofit staff about their organization's numbers.
        - Answer in one to three short, plain sentences. Be encouraging and specific.
        - Never write digits, amounts or percentages. The app shows the figures for the facts you cite. \
        Compare in words instead, like "more than the 7 days before" or "about the same".
        - If the figures can't answer the question, say so plainly. Never guess or invent numbers.
        - Speak to the reader as "you". Never write "we", "us", "our" or "let's".
        - Don't mention dates or time periods, and don't restate amounts in words \
        (no "half", "twice" or "percent"); the app shows them with the figures.
        """

    private let facts: [Fact]
    private var session: LanguageModelSession
    private var usesTool = true

    init(facts: [Fact]) {
        self.facts = facts
        session = LanguageModelSession(
            tools: [WeeklyNumbersTool(facts: facts)],
            instructions: Self.instructions + "\nCall getWeeklyNumbers to look up figures; it is the only source of numbers."
        )
    }

    func answer(_ question: String) async throws -> NumbersAnswer {
        var reply = try await respond(to: question)
        if !InsightCheck.isSafeCopy(reply.answer) {
            // One reminder; if it still breaks the rules, InsightCheck replaces the text.
            reply = try await respond(to: "Please answer again in plain words: no digits, no amounts or "
                + "time periods, no \"we\" or \"our\". List the ids of the facts you used.")
        }
        return InsightCheck.answer(text: reply.answer, factIDs: reply.factIDs, facts: facts)
    }

    private func respond(to prompt: String) async throws -> GeneratedAnswer {
        do {
            return try await session.respond(to: prompt, generating: GeneratedAnswer.self).content
        } catch where usesTool && !(error is CancellationError) {
            // Tool calling isn't available everywhere (e.g. some simulators). The figures are
            // few, so hand the same precomputed lines over in the instructions and try again.
            usesTool = false
            session = LanguageModelSession(instructions: Self.instructions + "\nThe only figures you have:\n"
                + facts.map(InsightWriter.promptLine).joined(separator: "\n"))
            return try await session.respond(to: prompt, generating: GeneratedAnswer.self).content
        }
    }
}

/// Gives the model precomputed figures only. It never calculates anything itself.
nonisolated struct WeeklyNumbersTool: Tool {
    let name = "getWeeklyNumbers"
    let description = """
        Looks up the organization's figures: total supporters, new joins, money raised, \
        average gift and email open rate, for the last 7 days and the 7 days before.
        """

    @Generable
    nonisolated struct Arguments {
        @Guide(description: "Which figure to look up, or all of them",
               .anyOf(["all", "supporters", "newJoins", "raised", "averageGift", "emailOpenRate"]))
        var figure: String
    }

    let facts: [Fact]

    @concurrent func call(arguments: Arguments) async throws -> String {
        let matching = facts.filter { arguments.figure == "all" || $0.metric.rawValue == arguments.figure }
        guard !matching.isEmpty else { return "That figure isn't available." }
        return matching.map(InsightWriter.promptLine).joined(separator: "\n")
    }
}

// MARK: - Generated types

@Generable
nonisolated struct GeneratedInsight {
    @Guide(description: "A short headline saying what changed, at most eight words, with no numbers")
    var title: String
    @Guide(description: "One or two sentences on what changed and why it matters to the reader, with no numbers")
    var explanation: String
    @Guide(description: "One practical next step the reader can take in the next few days, with no numbers")
    var suggestedAction: String
}

@Generable
nonisolated struct GeneratedAnswer {
    @Guide(description: "Ids of the facts your answer is about, copied exactly; empty if none")
    var factIDs: [String]
    @Guide(description: "Your answer in one to three short sentences, with no numbers")
    var answer: String
}
