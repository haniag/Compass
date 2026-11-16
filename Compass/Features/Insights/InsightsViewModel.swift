//
//  InsightsViewModel.swift
//  Compass
//
//  The digest, written from the facts Pulse loaded: by Apple Intelligence when
//  it's available, from templates otherwise.
//

import Foundation
import Observation

@Observable
final class InsightsViewModel {
    enum Author {
        case appleIntelligence
        case templates
    }

    private(set) var insights: [Insight] = []
    /// The facts the insights and answers were written from.
    private(set) var facts: [Fact] = []
    private(set) var author: Author = .templates
    private(set) var isWriting = false
    private(set) var aiStatus = InsightWriter.status

    private var writtenFrom: [Fact]?
    private var currentJob = UUID()

    // MARK: Digest

    /// Rewrites the digest when the numbers change. Cheap to call again with the same facts.
    func update(facts newFacts: [Fact]) async {
        aiStatus = InsightWriter.status
        guard newFacts != writtenFrom else { return }

        let job = UUID()
        currentJob = job
        facts = newFacts

        let highlights = InsightRules.highlights(from: newFacts)
        guard aiStatus == .available, !highlights.isEmpty else {
            insights = TemplateInsights.digest(facts: newFacts)
            author = .templates
            writtenFrom = newFacts
            isWriting = false
            return
        }

        // The template cards show at once; each fact's card is swapped for the model's
        // words as soon as its draft passes the check. One fact per request, as before.
        isWriting = true
        var drafts: [InsightDraft] = []
        show(drafts, highlights: highlights, facts: newFacts)
        for fact in highlights {
            drafts += (try? await InsightWriter.drafts(about: [fact])) ?? []
            // A newer call took over, or the screen went away; it'll be written next time.
            guard currentJob == job, !Task.isCancelled else { return }
            show(drafts, highlights: highlights, facts: newFacts)
        }
        writtenFrom = newFacts
        isWriting = false
    }

    /// The digest from the drafts written so far: checked drafts, templates for the
    /// rest, then the steady note. With every draft in, this is the finished digest.
    private func show(_ drafts: [InsightDraft], highlights: [Fact], facts: [Fact]) {
        let written = InsightCheck.validated(drafts, facts: highlights)
        let steady = TemplateInsights.steadyNote(facts: facts, highlights: highlights)
        insights = InsightCheck.filling(written, highlights: highlights) + [steady].compactMap { $0 }
        author = written.isEmpty ? .templates : .appleIntelligence
    }
}
