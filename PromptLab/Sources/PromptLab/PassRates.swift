//
//  PassRates.swift
//  PromptLab
//
//  How often the app's own briefing and digest drafts pass the app's own checks.
//  The files in AppCode/ are symlinks to the app's sources (Compass/), so this runs
//  the real instructions, prompts, retry loops, BriefingCheck and InsightCheck.
//
//    swift run -c release --package-path PromptLab PromptLab --pass-rates --runs=4 --label=baseline
//
//  --runs is per set of facts; there are six sets (good, bad and mixed numbers, for
//  the last 7 days and for last month), so --runs=4 gives 24 briefings and about 70
//  digest drafts.
//

import Foundation
import FoundationModels

enum PassRates {
    struct FactSet {
        let name: String
        let facts: [Fact]
    }

    /// Fake numbers. Each set has the five Pulse figures.
    static let factSets: [FactSet] = [Fact.Period.lastSevenDays, .lastMonth].flatMap { period -> [FactSet] in
        let month = period == .lastMonth
        func count(_ metric: Fact.Metric, _ now: Decimal, _ before: Decimal) -> Fact {
            Fact(metric: metric, unit: .count, value: now, baseline: before, period: period)
        }
        func money(_ metric: Fact.Metric, _ now: Decimal, _ before: Decimal) -> Fact {
            Fact(metric: metric, unit: .money(currencyCode: "USD"), value: now, baseline: before, period: period)
        }
        func rate(_ now: Decimal, _ before: Decimal) -> Fact {
            Fact(metric: .emailOpenRate, unit: .percent, value: now, baseline: before, period: period)
        }
        let scale: Decimal = month ? 4 : 1
        return [
            FactSet(name: "good, \(period.title.lowercased())", facts: [
                count(.supporters, 48_312, 48_098 - (month ? 600 : 0)),
                count(.newJoins, 386 * scale, 342 * scale),
                money(.raised, 23_480 * scale, 21_740 * scale),
                money(.averageGift, Decimal(string: "52.30")!, Decimal(string: "49.80")!),
                rate(Decimal(string: "41.2")!, Decimal(string: "39.6")!),
            ]),
            FactSet(name: "bad, \(period.title.lowercased())", facts: [
                count(.supporters, 48_050, 48_098 + (month ? 300 : 0)),
                count(.newJoins, 210 * scale, 342 * scale),
                money(.raised, 15_900 * scale, 21_740 * scale),
                money(.averageGift, Decimal(string: "41.10")!, Decimal(string: "49.80")!),
                rate(Decimal(string: "33.4")!, Decimal(string: "39.6")!),
            ]),
            FactSet(name: "mixed, \(period.title.lowercased())", facts: [
                count(.supporters, 48_312, 48_098),
                count(.newJoins, 386 * scale, 342 * scale),
                money(.raised, 18_200 * scale, 21_740 * scale),
                money(.averageGift, Decimal(string: "52.30")!, Decimal(string: "49.80")!),
                rate(Decimal(string: "38.2")!, Decimal(string: "39.6")!),
            ]),
        ]
    }

    struct Tally {
        /// Pieces of text asked for (briefings, or digest facts).
        var pieces = 0
        /// Passed on the first try.
        var firstTry = 0
        /// Passed within the app's 3 tries.
        var withinThree = 0
        /// Every model call.
        var tries = 0
        var failedCalls = 0
        var seconds = 0.0
    }

    struct Rejection {
        let set: String
        let text: String
        let reasons: [String]
    }

    static func run(runs: Int, label: String) async throws {
        var briefing: [String: Tally] = [:]
        var digest: [String: Tally] = [:]
        var reasons: [String: Int] = [:]
        var rejections: [Rejection] = []
        var errors: [String: Int] = [:]

        for set in factSets {
            for run in 1...runs {
                print("\(set.name) run \(run)/\(runs): briefing…", terminator: " ")
                fflush(stdout)
                var attempts: [InsightWriter.Attempt] = []
                var start = Date()
                let text = await BriefingWriter.briefing(from: set.facts) { attempts.append($0) }
                briefing[set.name, default: Tally()].record(attempts, final: text != nil, seconds: Date().timeIntervalSince(start))
                for attempt in attempts {
                    if let error = attempt.error { errors[short(error), default: 0] += 1 }
                    guard !attempt.passed, let text = attempt.text else { continue }
                    let why = attempt.reason
                    reasons["Briefing: " + attempt.reasonKind, default: 0] += 1
                    rejections.append(Rejection(set: set.name, text: text, reasons: [why]))
                }
                print(text == nil ? "failed after \(attempts.count)" : "ok after \(attempts.count)", terminator: "; digest… ")
                fflush(stdout)

                let highlights = InsightRules.highlights(from: set.facts)
                attempts = []
                start = Date()
                let drafts = (try? await InsightWriter.drafts(about: highlights) { attempts.append($0) }) ?? []
                let seconds = Date().timeIntervalSince(start)
                for fact in highlights {
                    let mine = attempts.filter { $0.factID == fact.id }
                    let passed = InsightCheck.validated(drafts.filter { $0.factIDs == [fact.id] }, facts: [fact]).count == 1
                    digest[set.name, default: Tally()].record(mine, final: passed, seconds: seconds / Double(highlights.count))
                    for attempt in mine {
                        if let error = attempt.error { errors[short(error), default: 0] += 1 }
                        guard !attempt.passed, let text = attempt.text else { continue }
                        let why = attempt.reason
                        reasons["Digest: " + attempt.reasonKind, default: 0] += 1
                        rejections.append(Rejection(set: "\(set.name), \(fact.metric.rawValue)", text: text, reasons: [why]))
                    }
                }
                print("\(attempts.filter(\.passed).count)/\(highlights.count) facts passed")
            }
        }

        let report = makeReport(label: label, runs: runs, briefing: briefing, digest: digest,
                                reasons: reasons, rejections: rejections, errors: errors)
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Results")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)
            .dateSeparator(.dash).timeSeparator(.omitted).dateTimeSeparator(.standard))
        let file = folder.appending(path: "pass-rates-\(label)-\(stamp).md")
        try report.write(to: file, atomically: true, encoding: .utf8)
        print("\nReport: \(file.path)")
    }

    private static func short(_ error: String) -> String { String(error.prefix(120)) }

    // MARK: Report

    private static func makeReport(label: String, runs: Int, briefing: [String: Tally], digest: [String: Tally],
                                   reasons: [String: Int], rejections: [Rejection], errors: [String: Int]) -> String {
        let model = SystemLanguageModel.default
        var lines = [
            "# Pass rates: \(label)", "",
            "Run \(Date().formatted(date: .abbreviated, time: .shortened)) on this Mac's on-device model "
                + "(macOS \(ProcessInfo.processInfo.operatingSystemVersionString)). Context window: \(model.contextSize) tokens. "
                + "\(runs) runs per set of facts.",
            "",
            "The app's own instructions, prompts, retry loops and checks (symlinked from `Compass/`). "
                + "**First try** is how often one model answer passes the check. **Within 3 tries** is how often the "
                + "app ends up showing generated text (otherwise it shows the template).",
        ]
        for (title, tallies) in [("Briefing (BriefingCheck)", briefing), ("Digest drafts (InsightCheck), per fact", digest)] {
            lines += ["", "## \(title)", "",
                      "| Facts | Pieces | First try | Within 3 tries | Avg tries | Failed calls | Avg time |",
                      "|---|---|---|---|---|---|---|"]
            var total = Tally()
            for set in factSets {
                guard let t = tallies[set.name] else { continue }
                lines.append(row(set.name, t))
                total.add(t)
            }
            lines.append(row("**All**", total))
        }

        lines += ["", "## Rejection reasons", "",
                  "Every rejected answer, by the first problem the app's check found in it "
                      + "(`FigureCheck.Problem`, the same reason the app logs and tells the model on a retry). "
                      + "Retries are told what was wrong, in the same session.", "",
                  "| Reason | Count |", "|---|---|"]
        for (reason, count) in reasons.sorted(by: { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }) {
            lines.append("| \(reason) | \(count) |")
        }
        if !errors.isEmpty {
            lines += ["", "## Model errors", "", "| Error | Count |", "|---|---|"]
            for (error, count) in errors.sorted(by: { $0.value > $1.value }) {
                lines.append("| \(error.replacingOccurrences(of: "|", with: "/")) | \(count) |")
            }
        }
        lines += ["", "## Rejected answers (up to 25)", ""]
        for rejection in rejections.prefix(25) {
            lines.append("- *\(rejection.set)* — \(rejection.reasons.joined(separator: "; ")): \(rejection.text)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func row(_ name: String, _ t: Tally) -> String {
        func percent(_ n: Int) -> String { t.pieces == 0 ? "–" : "\(n)/\(t.pieces) (\(Int((Double(n) / Double(t.pieces) * 100).rounded()))%)" }
        let avgTries = t.pieces == 0 ? 0 : Double(t.tries) / Double(t.pieces)
        let avgTime = t.pieces == 0 ? 0 : t.seconds / Double(t.pieces)
        return "| \(name) | \(t.pieces) | \(percent(t.firstTry)) | \(percent(t.withinThree)) | "
            + String(format: "%.2f", avgTries) + " | \(t.failedCalls) | " + String(format: "%.1fs", avgTime) + " |"
    }
}

extension PassRates.Tally {
    mutating func record(_ attempts: [InsightWriter.Attempt], final: Bool, seconds: Double) {
        pieces += 1
        if attempts.first?.passed == true { firstTry += 1 }
        if final { withinThree += 1 }
        tries += attempts.count
        failedCalls += attempts.filter { $0.error != nil }.count
        self.seconds += seconds
    }

    mutating func add(_ other: Self) {
        pieces += other.pieces
        firstTry += other.firstTry
        withinThree += other.withinThree
        tries += other.tries
        failedCalls += other.failedCalls
        seconds += other.seconds
    }
}

extension InsightWriter.Attempt {
    /// The check's reason, with the part of a digest draft it was found in.
    var reason: String {
        let problem = problem.map(String.init(describing:)) ?? "fact or severity"
        return part.map { "\($0): \(problem)" } ?? problem
    }

    /// The reason without the word or figure, so rejections can be counted by kind.
    var reasonKind: String {
        let kind: String
        switch problem {
        case .empty?: kind = "a part was empty"
        case .tooLong?: kind = "too long"
        case .speaksAsOrganization?: kind = "spoke as \"we\"/\"our\""
        case .wrongTimeWords(let word)?: kind = "wrong time words (\(word))"
        case .amountInWords(let word)?: kind = "amount in words (\(word))"
        case .percentWithoutNumber?: kind = "\"percent\" without a figure"
        case .unknownFigure?: kind = "quoted a figure that isn't in the facts"
        case .wrongDirection?: kind = "said a figure moved the wrong way"
        case nil: kind = "fact or severity"
        }
        return part.map { "\($0): \(kind)" } ?? kind
    }
}
