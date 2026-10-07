//
//  Insight.swift
//  Compass
//
//  A plain-language observation about the numbers. Written today by templates
//  (TemplateInsights); later also by the on-device model, with the same shape.
//

import Foundation

nonisolated struct Insight: Identifiable, Hashable, Sendable {
    enum Severity: Hashable, Sendable {
        /// "Needs attention": something got worse.
        case attention
        /// "Opportunity": something good that's worth acting on now.
        case opportunity
        /// "Good news".
        case good
        /// "Steady": nothing moved much.
        case neutral
    }

    let id: String
    let title: String
    let severity: Severity
    /// The facts this insight is about. Figures shown next to it come from these.
    let factIDs: [String]
    let explanation: String
    let suggestedAction: String?
    /// True when Apple Intelligence wrote the words; false for templates.
    var isGenerated = false
}
