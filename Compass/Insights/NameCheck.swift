//
//  NameCheck.swift
//  Compass
//
//  Generated summaries may name an email or a donation page, but only one Swift handed
//  over, inside quotation marks, word for word. Used by the Email and Giving summaries.
//

import Foundation

nonisolated enum NameCheck {
    /// Longer names are left out: they'd crowd a two-sentence summary.
    static let longestName = 60

    /// The name as a summary may quote it. Nil when it can't be quoted safely: empty,
    /// very long, or with quotation marks of its own.
    static func quotable(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= longestName,
              !trimmed.contains(where: { "\"“”".contains($0) })
        else { return nil }
        return trimmed
    }

    /// What stands in for the first, second… name once it's been checked: plain letters,
    /// so the figure check doesn't trip over "Fall Appeal 2026" or "Weekly news".
    static func placeholder(_ index: Int) -> String {
        "name" + String(UnicodeScalar(UInt8(97 + index % 26)))
    }

    /// `text` with every allowed name swapped for its placeholder. Nil when something in
    /// quotation marks isn't one of `names`, or a quotation mark is left open.
    static func replacingNames(_ names: [String], in text: String) -> String? {
        var rest = text.replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"")
        for match in rest.matches(of: /"([^"]*)"/) {
            let quoted = String(match.output.1).trimmingCharacters(in: .whitespaces)
            // American style puts the comma inside the quotation marks.
            let withoutComma = quoted.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
            guard names.contains(quoted) || names.contains(withoutComma) else { return nil }
        }
        guard rest.filter({ $0 == "\"" }).count.isMultiple(of: 2) else { return nil }
        // Longest first, so "Fall Appeal" doesn't eat the start of "Fall Appeal 2026".
        let ordered = names.enumerated().sorted { $0.element.count > $1.element.count }
        for (index, name) in ordered {
            rest = rest.replacingOccurrences(of: name, with: " \(placeholder(index)) ", options: .caseInsensitive)
        }
        return rest.replacingOccurrences(of: "\"", with: " ")
    }
}
