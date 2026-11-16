//
//  FigureCheck.swift
//  Compass
//
//  Generated copy may quote figures, but only ones Swift already worked out and
//  the app shows for those facts. Used by Pulse's briefing and the Insights digest.
//

import Foundation

nonisolated enum FigureCheck {
    /// Why a piece of generated text was rejected. `description` is for the `AI` log;
    /// `correction(for:)` is the short note the model gets on a retry.
    enum Problem: Equatable, Sendable, CustomStringConvertible {
        /// Nothing was written (an empty title or explanation).
        case empty
        /// More words than the briefing allows.
        case tooLong(maxWords: Int)
        /// "we", "our", "let's": the app speaks to the team, it isn't part of it.
        case speaksAsOrganization(word: String)
        /// "week", "today", "this month", or "month"/"yesterday" outside their own period.
        case wrongTimeWords(word: String)
        /// "hundreds", "a third", or "half"/"double" when the figures don't show that change.
        case amountInWords(word: String)
        /// "percent" with no number right before it ("a few percent").
        case percentWithoutNumber
        /// A number that isn't one of the figures the app shows.
        case unknownFigure(Decimal)
        /// A change said to move the opposite way: "rose 13%" when it fell 13%.
        case wrongDirection(figure: Decimal, actuallyUp: Bool)

        var description: String {
            switch self {
            case .empty: "a part was empty"
            case .tooLong(let max): "longer than \(max) words"
            case .speaksAsOrganization(let word): "spoke as the organization (\"\(word)\")"
            case .wrongTimeWords(let word): "named the wrong time period (\"\(word)\")"
            case .amountInWords(let word): "put an amount into words (\"\(word)\")"
            case .percentWithoutNumber: "said \"percent\" without a figure"
            case .unknownFigure(let number): "quoted \(number), which isn't one of the figures"
            case .wrongDirection(let number, let up): "said the change of \(number) went \(up ? "down" : "up")"
            }
        }

        /// One or two sentences telling the model what to fix. Names only words and
        /// figures it wrote itself, or figures it was given.
        func correction(for period: Fact.Period?) -> String {
            switch self {
            case .empty:
                return "Part of it was empty. Fill in every part."
            case .tooLong:
                return "It was too long. Keep it to two short sentences."
            case .speaksAsOrganization(let word):
                return "It said \"\(word)\". Speak to the reader as \"you\" and \"your supporters\"; never write \"we\", \"us\", \"our\" or \"let's\"."
            case .wrongTimeWords(let word):
                let instead = period.map { " Say \"\($0.during)\" instead." } ?? ""
                return "It said \"\(word)\", which is the wrong time period.\(instead)"
            case .amountInWords(let word):
                return "It said \"\(word)\". Don't put amounts into words; quote the figures with digits, exactly as they are written."
            case .percentWithoutNumber:
                return "It said \"percent\" without a figure. Quote percentages exactly as they are written, or leave them out."
            case .unknownFigure(let number):
                return "It quoted \(number), which isn't one of the figures you were given. Quote only those figures, exactly as they are written, and never work out a new one."
            case .wrongDirection(let number, let up):
                return "The change of \(number) went \(up ? "up" : "down"), but the text said it went \(up ? "down" : "up")."
            }
        }
    }

    /// True when every number in `text` is one of these facts' figures, and the text
    /// doesn't speak as "we", name the wrong time period, or work out amounts in words.
    static func quotesOnlyFigures(of facts: [Fact], in text: String) -> Bool {
        problem(quoting: facts, in: text) == nil
    }

    /// Why `quotesOnlyFigures` would say false, or nil when it says true.
    static func problem(quoting facts: [Fact], in text: String) -> Problem? {
        problem(allowing: allowedNumbers(facts), period: facts.first?.period,
                showsHalving: facts.contains { $0.changed(.down, by: "50%") },
                showsDoubling: facts.contains { $0.changed(.up, by: "100%") },
                in: text)
    }

    /// The same check for figures that aren't Facts (the Email summary): `allowed` is every
    /// number the text may quote. "half" passes only with `showsHalving`, "double" and
    /// "twice" only with `showsDoubling`.
    static func quotesOnly(_ allowed: Set<Decimal>, period: Fact.Period?,
                           showsHalving: Bool, showsDoubling: Bool, in text: String) -> Bool {
        problem(allowing: allowed, period: period, showsHalving: showsHalving,
                showsDoubling: showsDoubling, in: text) == nil
    }

    /// Why `quotesOnly` would say false (the first problem in the text), or nil.
    static func problem(allowing allowed: Set<Decimal>, period: Fact.Period?,
                        showsHalving: Bool, showsDoubling: Bool, in text: String) -> Problem? {
        // Words and digit runs, in order: "fifty percent" → ["fifty", "percent"].
        let tokens = text.lowercased().replacingOccurrences(of: "’", with: "'")
            .split { !$0.isLetter && !$0.isNumber && $0 != "'" }
            .map(String.init)
        // "yesterday" and "month" are the right words only for their own period, and
        // "this month" never is: the month the figures cover is over.
        var timeWords = self.timeWords
        if period == .yesterday { timeWords.remove("yesterday") }
        if period != .lastMonth { timeWords.formUnion(["month", "months", "month's", "monthly"]) }
        for (index, token) in tokens.enumerated() {
            if organizationWords.contains(token) { return .speaksAsOrganization(word: token) }
            if timeWords.contains(token) { return .wrongTimeWords(word: token) }
            if token == "this", index + 1 < tokens.count, tokens[index + 1] == "month" {
                return .wrongTimeWords(word: "this month")
            }
            if amountWords.contains(token) { return .amountInWords(word: token) }
            // "half" and "doubled" are figures too: fine only when the app shows that change.
            if halfWords.contains(token), !showsHalving { return .amountInWords(word: token) }
            if doubleWords.contains(token), !showsDoubling { return .amountInWords(word: token) }
            // "percent" only right after a number ("fifty percent", "50 percent"), never "a few percent".
            if token == "percent" || token == "percentage" {
                guard index > 0 else { return .percentWithoutNumber }
                let before = tokens[index - 1]
                guard before.first?.isNumber == true || spelledNumbers[before] != nil else { return .percentWithoutNumber }
            }
        }

        // "nine" is fine when 9 is one of the figures. "one" is left alone: it's mostly not a figure.
        let spelled = tokens.compactMap { spelledNumbers[$0] }
        if let unknown = (numbers(in: text) + spelled).first(where: { !allowed.contains($0) }) {
            return .unknownFigure(unknown)
        }
        return nil
    }

    /// False when the text says something "rose 13%" that fell 13%, or the other way
    /// round. It looks at the part of the sentence around each change ("…, though clicks
    /// slipped 0.4 pts to 4.9%") for a word that points the wrong way.
    static func agreesOnDirections(_ text: String, changes: [FactChange]) -> Bool {
        directionProblem(text, changes: changes) == nil
    }

    /// Why `agreesOnDirections` would say false, or nil.
    static func directionProblem(_ text: String, changes: [FactChange]) -> Problem? {
        let parts = text.lowercased()
            .split(separator: /[.,;:!?]\s+|\s+(?:and|but|though|although|while|whereas|yet)\s+/)
            .map(String.init)
        let moves = changes.compactMap { change -> (number: Decimal, isUp: Bool)? in
            guard change.direction != .flat, let number = numbers(in: change.text).first else { return nil }
            return (number, change.direction == .up)
        }
        for move in moves {
            // Two figures that moved by the same amount in opposite directions can't be told apart.
            if moves.contains(where: { $0.number == move.number && $0.isUp != move.isUp }) { continue }
            for part in parts where numbers(in: part).contains(move.number) {
                let words = Set(part.split { !$0.isLetter }.map(String.init))
                let right = move.isUp ? upWords : downWords
                let wrong = move.isUp ? downWords : upWords
                if !words.isDisjoint(with: wrong), words.isDisjoint(with: right) {
                    return .wrongDirection(figure: move.number, actuallyUp: move.isUp)
                }
            }
        }
        return nil
    }

    private static let upWords: Set<String> = [
        "up", "rose", "rise", "risen", "rising", "climbed", "climbing", "grew", "grown", "growing",
        "increased", "increase", "higher", "gained", "jumped",
    ]
    private static let downWords: Set<String> = [
        "down", "fell", "fall", "fallen", "falling", "slipped", "slipping", "dropped", "drop",
        "dropping", "declined", "decreased", "decrease", "dipped", "lower", "slid", "lost",
    ]

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

    /// Speaking as the organization.
    private static let organizationWords: Set<String> = [
        "we", "we're", "we've", "we'll", "us", "our", "ours", "let's",
    ]
    /// The figures cover the chosen period, never today or a calendar week.
    private static let timeWords: Set<String> = [
        "today", "yesterday", "tonight", "week", "weeks", "week's", "weekly",
    ]
    /// Amounts in words the check can't match to a figure.
    private static let amountWords: Set<String> = [
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
