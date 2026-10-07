//
//  InsightsViewModel.swift
//  Compass
//
//  The weekly digest and "Ask about your numbers". Written from the facts Pulse
//  loaded: by Apple Intelligence when it's available, from templates otherwise.
//

import Foundation
import Observation

@Observable
final class InsightsViewModel {
    enum Author {
        case appleIntelligence
        case templates
    }

    struct Exchange: Identifiable {
        let id = UUID()
        let question: String
        var answer: NumbersAnswer?
        var failed = false
    }

    /// Longer questions are cut; the on-device model has a small context.
    private static let maxQuestionLength = 300

    private(set) var insights: [Insight] = []
    /// The facts the insights and answers were written from.
    private(set) var facts: [Fact] = []
    private(set) var author: Author = .templates
    private(set) var isWriting = false
    private(set) var aiStatus = InsightWriter.status
    private(set) var exchanges: [Exchange] = []
    private(set) var isAnswering = false
    var question = ""

    private var writtenFrom: [Fact]?
    private var currentJob = UUID()
    private var chat: NumbersChat?

    var canAsk: Bool { aiStatus == .available && !facts.isEmpty }

    // MARK: Digest

    /// Rewrites the digest when the numbers change. Cheap to call again with the same facts.
    func update(facts newFacts: [Fact]) async {
        aiStatus = InsightWriter.status
        guard newFacts != writtenFrom else { return }

        let job = UUID()
        currentJob = job
        facts = newFacts
        // New numbers: earlier answers may no longer be true.
        exchanges = []
        chat = nil

        let highlights = InsightRules.highlights(from: newFacts)
        guard aiStatus == .available, !highlights.isEmpty else {
            insights = TemplateInsights.digest(facts: newFacts)
            author = .templates
            writtenFrom = newFacts
            isWriting = false
            return
        }

        isWriting = true
        let drafts = (try? await InsightWriter.drafts(about: highlights)) ?? []
        // A newer call took over, or the screen went away; it'll be written next time.
        guard currentJob == job, !Task.isCancelled else { return }

        let written = InsightCheck.validated(drafts, facts: highlights)
        let steady = TemplateInsights.steadyNote(facts: newFacts, highlights: highlights)
        insights = InsightCheck.filling(written, highlights: highlights) + [steady].compactMap { $0 }
        author = written.isEmpty ? .templates : .appleIntelligence
        writtenFrom = newFacts
        isWriting = false
    }

    // MARK: Ask

    func ask() async {
        let text = String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxQuestionLength))
        guard !text.isEmpty, canAsk, !isAnswering else { return }
        question = ""

        let exchange = Exchange(question: text)
        exchanges.append(exchange)
        isAnswering = true
        defer { isAnswering = false }

        let chat = self.chat ?? NumbersChat(facts: facts)
        self.chat = chat
        let result: NumbersAnswer?
        do {
            result = try await chat.answer(text)
        } catch {
            // Start fresh next time (e.g. the conversation got too long).
            self.chat = nil
            result = nil
        }

        guard let index = exchanges.firstIndex(where: { $0.id == exchange.id }) else { return }
        if let result {
            exchanges[index].answer = result
        } else {
            exchanges[index].failed = true
        }
    }
}
