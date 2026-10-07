//
//  Lab.swift
//  PromptLab
//
//  Runs prompt variants on the on-device model and checks what comes back:
//  does it fit, how long it takes, and whether its numbers come from the input.
//

import Foundation
import FoundationModels

/// One way of asking. Variants of the same experiment share the data but change
/// one thing at a time (the prompt, the figures given, the output format).
struct Variant {
    let id: String
    let title: String
    let instructions: String
    let prompt: String
    /// Nil for free text; the output structure for guided generation.
    let schema: GenerationSchema?
    /// Asks the model once and returns its answer as readable text.
    let ask: (LanguageModelSession, String) async throws -> String
    /// Text Swift writes next to the answer (not checked, shown once in the report).
    var appendix: String? = nil
}

struct RunResult {
    let variant: Variant
    let attempt: Int
    let seconds: Double
    let inputTokens: Int
    /// Everything the session used: instructions, prompt, schema and the answer.
    let usedTokens: Int?
    let output: String?
    let error: String?
    let numbers: NumberCheck?
}

/// Numbers in the answer, sorted by where they came from.
struct NumberCheck {
    /// Given in the input (possibly rounded).
    var fromInput: [String] = []
    /// Not in the input, but a correct figure Swift worked out (the model did the maths right).
    var calculatedCorrectly: [String] = []
    /// Not in the input and not a correct figure: invented or miscalculated.
    var unsupported: [String] = []
}

enum Lab {
    static func run(_ variants: [Variant], attempts: Int, truth: String) async -> [RunResult] {
        let model = SystemLanguageModel.default
        var results: [RunResult] = []
        for variant in variants {
            for attempt in 1...attempts {
                print("\(variant.id) run \(attempt)/\(attempts): \(variant.title)…", terminator: " ")
                fflush(stdout)
                let result = await runOnce(variant, attempt: attempt, model: model, truth: truth)
                print(result.error ?? String(format: "%.1fs, %d tokens", result.seconds, result.usedTokens ?? 0))
                results.append(result)
            }
        }
        return results
    }

    private static func runOnce(_ variant: Variant, attempt: Int, model: SystemLanguageModel, truth: String) async -> RunResult {
        var inputTokens = 0
        do {
            inputTokens = try await model.tokenCount(for: Instructions(variant.instructions))
                + model.tokenCount(for: variant.prompt)
            if let schema = variant.schema {
                inputTokens += try await model.tokenCount(for: schema)
            }
        } catch {
            inputTokens = -1
        }

        let session = LanguageModelSession(instructions: variant.instructions)
        let start = Date()
        do {
            let output = try await variant.ask(session, variant.prompt)
            let seconds = Date().timeIntervalSince(start)
            let used = try? await model.tokenCount(for: session.transcript)
            let check = checkNumbers(in: output, input: variant.instructions + "\n" + variant.prompt, truth: truth)
            return RunResult(variant: variant, attempt: attempt, seconds: seconds, inputTokens: inputTokens,
                             usedTokens: used, output: output, error: nil, numbers: check)
        } catch {
            return RunResult(variant: variant, attempt: attempt, seconds: Date().timeIntervalSince(start),
                             inputTokens: inputTokens, usedTokens: nil, output: nil, error: describe(error), numbers: nil)
        }
    }

    static func describe(_ error: Error) -> String {
        guard let error = error as? LanguageModelSession.GenerationError else {
            return "Error: \(error.localizedDescription)"
        }
        switch error {
        case .exceededContextWindowSize: return "FAILED: ran out of context (the 4K-token window)"
        case .guardrailViolation: return "FAILED: blocked by a safety guardrail"
        case .refusal: return "FAILED: the model refused"
        case .decodingFailure: return "FAILED: couldn't fit its answer to the structure"
        case .unsupportedGuide: return "FAILED: unsupported generation guide"
        case .assetsUnavailable: return "FAILED: model not downloaded or unavailable"
        default: return "FAILED: \(error.localizedDescription)"
        }
    }

    // MARK: Number check

    /// Every number in `output` is looked up in the input, then in `truth` (correct
    /// figures the model wasn't given). A match allows rounding to the output's precision.
    static func checkNumbers(in output: String, input: String, truth: String) -> NumberCheck {
        let given = numbers(in: input).map(\.value)
        let correct = numbers(in: truth).map(\.value)
        var check = NumberCheck()
        for number in numbers(in: output, skippingListMarkers: true) {
            if given.contains(where: { matches(number, $0) }) {
                check.fromInput.append(number.text)
            } else if correct.contains(where: { matches(number, $0) }) {
                check.calculatedCorrectly.append(number.text)
            } else {
                check.unsupported.append(number.text)
            }
        }
        return check
    }

    private struct Number {
        let text: String
        let value: Double
        let decimals: Int
    }

    private static func numbers(in text: String, skippingListMarkers: Bool = false) -> [Number] {
        var text = text
        if skippingListMarkers {
            // "1. Diagnosis", "## 2) Causes": numbering, not figures.
            text = text.replacing(#/(?m)^[ \t#*]*\d+[.)][ \t]/#, with: "")
        }
        return text.matches(of: #/\d[\d,]*(?:\.\d+)?/#).compactMap { match in
            let raw = String(match.output).trimmingCharacters(in: CharacterSet(charactersIn: ","))
            let plain = raw.replacingOccurrences(of: ",", with: "")
            guard let value = Double(plain) else { return nil }
            let decimals = plain.split(separator: ".").dropFirst().first?.count ?? 0
            return Number(text: raw, value: value, decimals: decimals)
        }
    }

    private static func matches(_ number: Number, _ candidate: Double) -> Bool {
        let scale = pow(10, Double(number.decimals))
        return abs((candidate * scale).rounded() - number.value * scale) < 0.001
    }

    // MARK: Report

    /// A question asked of every answer, e.g. "Finds the spike send?" → "yes".
    typealias Check = (name: String, answer: (String) -> String)

    static func report(_ results: [RunResult], experiment: String, contextSize: Int, notes: String, checks: [Check]) -> String {
        var lines = ["# \(experiment)", "",
                     "Run \(Date().formatted(date: .abbreviated, time: .shortened)) on this Mac's on-device model "
                     + "(macOS \(ProcessInfo.processInfo.operatingSystemVersionString)). Context window: \(contextSize) tokens.",
                     "", notes, "",
                     "| Run | Input tokens | Used tokens | Time | " + checks.map(\.name).joined(separator: " | ")
                     + " | Numbers from input | Calculated right | Unsupported numbers | Result |",
                     "|---|---|---|---|" + String(repeating: "---|", count: checks.count) + "---|---|---|---|"]
        for r in results {
            let n = r.numbers
            let answers = checks.map { check in r.output.map(check.answer) ?? "–" }
            lines.append("| \(r.variant.id)\(r.attempt) | \(r.inputTokens) | \(r.usedTokens.map(String.init) ?? "–") | "
                         + String(format: "%.0fs", r.seconds) + " | " + answers.joined(separator: " | ")
                         + " | \(n?.fromInput.count ?? 0) | "
                         + "\(n?.calculatedCorrectly.count ?? 0) | \(n.map { $0.unsupported.joined(separator: ", ") } ?? "") | "
                         + "\(r.error ?? "ok") |")
        }
        var seen: Set<String> = []
        for r in results {
            if seen.insert(r.variant.id).inserted {
                lines += ["", "---", "", "## \(r.variant.id). \(r.variant.title)", "",
                          "<details><summary>Instructions and prompt</summary>", "", "```",
                          r.variant.instructions, "", r.variant.prompt, "```", "</details>"]
                if let appendix = r.variant.appendix {
                    lines += ["", "Written by Swift, shown with every answer below:", "", appendix]
                }
            }
            lines += ["", "### \(r.variant.id)\(r.attempt)", ""]
            if let error = r.error {
                lines.append("**\(error)**")
            } else {
                lines.append(r.output ?? "")
                if let n = r.numbers, !n.calculatedCorrectly.isEmpty || !n.unsupported.isEmpty {
                    lines += ["", "> Numbers the model worked out itself: correct \(n.calculatedCorrectly); "
                              + "not supported by the data \(n.unsupported)"]
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
