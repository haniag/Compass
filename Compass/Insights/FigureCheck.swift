//
//  FigureCheck.swift
//  Compass
//
//  Generated copy may quote figures, but only ones Swift already worked out and
//  the app shows for those facts. Used by Pulse's briefing and the Insights digest.
//

import Foundation

nonisolated enum FigureCheck {
    /// True when every number in `text` is one of these facts' figures, and the text
    /// doesn't speak as "we", name the wrong time period, or work out amounts in words.
    static func quotesOnlyFigures(of facts: [Fact], in text: String) -> Bool {
        let words = Set(text.lowercased()
            .split { !$0.isLetter && $0 != "’" && $0 != "'" }
            .map { $0.replacingOccurrences(of: "’", with: "'") })
        guard words.isDisjoint(with: bannedWords) else { return false }
        // "nine" is fine when 9 is one of the figures. "one" is left alone: it's mostly not a figure.
        let spelled = words.compactMap { spelledNumbers[$0] }
        return Set(numbers(in: text) + spelled).isSubset(of: allowedNumbers(facts))
    }

    /// Every figure the app shows for these facts, plus the 7 in "last 7 days".
    static func allowedNumbers(_ facts: [Fact]) -> Set<Decimal> {
        var allowed: Set<Decimal> = [7]
        for fact in facts {
            for text in [fact.formattedValue, fact.formattedBaseline, fact.change?.text].compactMap({ $0 }) {
                allowed.formUnion(numbers(in: text))
            }
        }
        return allowed
    }

    /// "$3,704 and 58.8%" → [3704, 58.8]. Currency signs, commas and % are ignored.
    static func numbers(in text: String) -> [Decimal] {
        text.matches(of: /\d[\d,]*(?:\.\d+)?/).compactMap { match in
            Decimal(string: match.output.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
        }
    }

    private static let bannedWords: Set<String> = [
        // Speaking as the organization.
        "we", "we're", "we've", "we'll", "us", "our", "ours", "let's",
        // The figures cover the last 7 days, not a day or a calendar week.
        "today", "yesterday", "tonight", "week", "weeks", "week's", "weekly",
        // Figures worked out by the model, or too big to check when spelled out.
        // "percent" too: figures are quoted as written ("13%"), and "a few percent" hides none.
        "half", "halved", "double", "doubled", "twice", "triple", "tripled", "third", "quarter",
        "percent", "percentage", "twenty", "thirty", "forty", "fifty", "hundred",
        "hundreds", "thousand", "thousands", "million", "millions", "dozen", "dozens",
    ]

    /// Small numbers the model likes to spell out; checked like digits.
    private static let spelledNumbers: [String: Decimal] = [
        "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
        "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
    ]
}
