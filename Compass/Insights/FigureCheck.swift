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
        // Words and digit runs, in order: "fifty percent" → ["fifty", "percent"].
        let tokens = text.lowercased().replacingOccurrences(of: "’", with: "'")
            .split { !$0.isLetter && !$0.isNumber && $0 != "'" }
            .map(String.init)
        let words = Set(tokens)
        // "yesterday" is the right word only when the figures are for yesterday.
        let banned = facts.first?.period == .yesterday ? bannedWords.subtracting(["yesterday"]) : bannedWords
        guard words.isDisjoint(with: banned) else { return false }

        // "half" and "doubled" are figures too: fine only when the app shows that change.
        if !words.isDisjoint(with: halfWords), !facts.contains(where: { $0.changed(.down, by: "50%") }) {
            return false
        }
        if !words.isDisjoint(with: doubleWords), !facts.contains(where: { $0.changed(.up, by: "100%") }) {
            return false
        }
        // "percent" only right after a number ("fifty percent", "50 percent"), never "a few percent".
        for (index, token) in tokens.enumerated() where token == "percent" || token == "percentage" {
            guard index > 0 else { return false }
            let before = tokens[index - 1]
            guard before.first?.isNumber == true || spelledNumbers[before] != nil else { return false }
        }

        // "nine" is fine when 9 is one of the figures. "one" is left alone: it's mostly not a figure.
        let spelled = tokens.compactMap { spelledNumbers[$0] }
        return Set(numbers(in: text) + spelled).isSubset(of: allowedNumbers(facts))
    }

    /// Every figure the app shows for these facts, plus the 7 in "last 7 days"
    /// (or the 30 in "last 30 days").
    static func allowedNumbers(_ facts: [Fact]) -> Set<Decimal> {
        var allowed: Set<Decimal> = []
        for fact in facts {
            allowed.formUnion(numbers(in: "\(fact.period.during) \(fact.period.before)"))
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
        // The figures cover the chosen period, never today or a calendar week.
        "today", "yesterday", "tonight", "week", "weeks", "week's", "weekly",
        // Amounts in words the check can't match to a figure.
        "triple", "tripled", "third", "thirds", "quarter", "quarters",
        "hundred", "hundreds", "thousand", "thousands", "million", "millions", "dozen", "dozens",
    ]

    /// Allowed only when a figure fell 50%.
    private static let halfWords: Set<String> = ["half", "halved", "halving"]
    /// Allowed only when a figure rose 100%.
    private static let doubleWords: Set<String> = ["double", "doubled", "doubling", "twice"]

    /// Numbers the model likes to spell out; checked like digits.
    private static let spelledNumbers: [String: Decimal] = [
        "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
        "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]
}

private nonisolated extension Fact {
    /// True when the app shows this change: `changed(.down, by: "50%")` for 8 → 4.
    func changed(_ direction: FactChange.Direction, by text: String) -> Bool {
        change?.direction == direction && change?.text == text
    }
}
