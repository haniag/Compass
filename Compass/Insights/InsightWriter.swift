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
        /// Turned on, but the model is still downloading or setting itself up.
        case gettingReady
        /// Not supported here, or not in this language.
        case unavailable
    }

    static var status: Status {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale() ? .available : .unavailable
        case .unavailable(.appleIntelligenceNotEnabled):
            return .turnedOff
        case .unavailable(.modelNotReady):
            return .gettingReady
        case .unavailable:
            return .unavailable
        }
    }

    /// True when the conversation no longer fits the model's context window.
    /// Starting a new session with the same question works then.
    static func isContextFull(_ error: Error) -> Bool {
        // iOS 27 throws LanguageModelError; iOS 26 (the app still runs there) the older GenerationError.
        if #available(iOS 27.0, macOS 27.0, *), case .contextSizeExceeded = error as? LanguageModelError {
            return true
        }
        if case .exceededContextWindowSize = error as? LanguageModelSession.GenerationError { return true }
        return false
    }

    /// The worked example uses the same period words as the fact, e.g. "in the last 7 days".
    static func digestInstructions(for period: Fact.Period) -> String {
        let during = period.during
        let before = period.duringBefore
        return """
        You write one insight for a digest read by the staff of a nonprofit: \
        fundraisers, email managers and campaigners. The app has already worked out \
        the numbers; you only put one fact into words.
        - Speak to the reader as "you" and "your supporters". Never write "we", "us", "our" or "let's".
        - Use plain, warm, specific words: supporters, gifts, appeals, actions.
        - You may quote the fact's figures, with digits, exactly as they are written in the fact. \
        Never calculate, round or estimate a new figure.
        - Say "\(during)" or "\(period.before)". \(period.wordsToAvoid)
        - Say only what the fact shows: whether it went up or down, and why that matters. \
        Don't praise or mention anything else (appeals, emails, campaigns), don't guess at causes, \
        and don't compare with other organizations.
        - Keep the next step out of the explanation; it goes only in the suggested action.

        An example of the style only, about a figure the app doesn't track; never copy its words:
        Fact: Event registrations: 64 \(during), 80 \(before) (down 20%). This needs attention.
        title: Event registrations slipped 20%
        explanation: 64 people registered \(during), down from 80 \(before). \
        Fewer registrations now can mean a quieter room on the day.
        suggestedAction: Remind past attendees that the event is coming up.
        """
    }

    /// One try at a briefing or a digest draft, for PromptLab's measurements. The app ignores these.
    struct Attempt: Sendable {
        /// The digest fact the draft is about; nil for the briefing.
        let factID: String?
        /// 1, 2 or 3.
        let number: Int
        /// What the model wrote (a draft's title, explanation and action joined with " | ").
        let text: String?
        /// Why the model call failed, when it did.
        let error: String?
        /// Why the check rejected the text, when it did, and in which part of a digest draft.
        let problem: FigureCheck.Problem?
        /// "title", "explanation" or "suggestedAction" for a digest draft; nil for the briefing.
        var part: String? = nil
        let passed: Bool
    }

    /// Up to one draft per fact InsightRules picked, in the same order. Each fact gets its own
    /// short request: the on-device model is much more reliable with one thing at a time.
    /// The fact ID and severity come from Swift; the model writes only the words.
    /// `onAttempt` hears about every try (PromptLab measures with it; the app doesn't use it).
    static func drafts(about highlights: [Fact],
                       onAttempt: (Attempt) -> Void = { _ in }) async throws -> [InsightDraft] {
        var drafts: [InsightDraft] = []
        for fact in highlights {
            // One session per fact. Two retries if the words break the copy rules, each telling
            // the model what was wrong; after that the template is used.
            let session = LanguageModelSession(instructions: digestInstructions(for: fact.period))
            var request = prompt(for: fact)
            for attempt in 1...3 {
                try Task.checkCancellation()
                let draft: InsightDraft
                do {
                    draft = try await self.draft(about: fact, in: session, request: request)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    // The model refused or failed on this fact (e.g. a safety check).
                    // Skip it; its template insight fills the gap.
                    log.error("Draft for \(fact.id, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                    onAttempt(Attempt(factID: fact.id, number: attempt, text: nil, error: String(describing: error),
                                      problem: nil, passed: false))
                    break
                }
                let passed = InsightCheck.validated([draft], facts: [fact]).count == 1
                let rejection = passed ? nil : InsightCheck.wordingProblem(in: draft, citedFacts: [fact])
                onAttempt(Attempt(factID: fact.id, number: attempt,
                                  text: [draft.title, draft.explanation, draft.suggestedAction ?? ""].joined(separator: " | "),
                                  error: nil, problem: rejection?.problem, part: rejection?.part, passed: passed))
                if !passed {
                    let reason = rejection.map { "\($0.part): \($0.problem)" } ?? "fact or severity"
                    log.notice("Draft for \(fact.id, privacy: .public) broke the copy rules (attempt \(attempt), \(reason, privacy: .public)): \(draft.title, privacy: .public) | \(draft.explanation, privacy: .public) | \(draft.suggestedAction ?? "", privacy: .public)")
                }
                if passed || attempt == 3 {
                    drafts.append(draft)
                    break
                }
                request = correction(rejection, period: fact.period)
            }
        }
        return drafts
    }

    /// The follow-up after a rejected draft: which part was wrong and why, then the same request again.
    static func correction(_ rejection: (part: String, problem: FigureCheck.Problem)?, period: Fact.Period) -> String {
        let what = rejection.map { "The \($0.part) can't be used. \($0.problem.correction(for: period))" }
            ?? "That insight can't be used."
        return what + " Write the title, explanation and suggestedAction again about the same fact, following every rule."
    }

    private static func draft(about fact: Fact, in session: LanguageModelSession,
                              request: String) async throws -> InsightDraft {
        let words = try await session.respond(
            to: request,
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
    static func instructions(for period: Fact.Period) -> String {
        """
        You answer questions from nonprofit staff about their organization's numbers.
        - Answer in one to three short, plain sentences. Be encouraging and specific.
        - Never write digits, amounts or percentages. The app shows the figures for the facts you cite. \
        Compare in words instead, like "more than \(period.before)" or "about the same".
        - If the figures can't answer the question, say so plainly. Never guess or invent numbers.
        - Speak to the reader as "you". Never write "we", "us", "our" or "let's".
        - Don't mention dates or time periods, and don't restate amounts in words \
        (no "half", "twice" or "percent"); the app shows them with the figures.
        """
    }

    private let facts: [Fact]
    private let instructions: String
    private var session: LanguageModelSession
    private var usesTool = true

    init(facts: [Fact]) {
        self.facts = facts
        instructions = Self.instructions(for: facts.first?.period ?? .lastSevenDays)
        session = LanguageModelSession(
            tools: [NumbersTool(facts: facts)],
            instructions: instructions + "\nCall getNumbers to look up figures; it is the only source of numbers."
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
        } catch where usesTool && !(error is CancellationError) && !InsightWriter.isContextFull(error) {
            // (A full context isn't a tool problem: InsightsViewModel starts a new chat for it.)
            // Tool calling isn't available everywhere (e.g. some simulators). The figures are
            // few, so hand the same precomputed lines over in the instructions and try again.
            usesTool = false
            session = LanguageModelSession(instructions: instructions + "\nThe only figures you have:\n"
                + facts.map(InsightWriter.promptLine).joined(separator: "\n"))
            return try await session.respond(to: prompt, generating: GeneratedAnswer.self).content
        }
    }
}

/// Gives the model precomputed figures only. It never calculates anything itself.
nonisolated struct NumbersTool: Tool {
    let name = "getNumbers"
    var description: String {
        let period = facts.first?.period ?? .lastSevenDays
        return """
            Looks up the organization's figures: total supporters, new joins, money raised, \
            average gift and email open rate, for \(period.title.lowercased()) and \(period.before).
            """
    }

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
    @Guide(description: "A short headline saying what changed, at most eight words")
    var title: String
    @Guide(description: "One or two sentences on what changed and why it matters to the reader, quoting figures exactly as written in the fact")
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
