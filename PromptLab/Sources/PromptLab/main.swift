//
//  main.swift
//  PromptLab
//
//  Runs the bounce-rate experiment and saves a report to PromptLab/Results/.
//  Arguments: which variants to run (e.g. "CD"; default all), and --runs=N (default 3).
//

import Foundation
import FoundationModels

let arguments = CommandLine.arguments.dropFirst()
let runs = arguments.first { $0.hasPrefix("--runs=") }.flatMap { Int($0.dropFirst(7)) } ?? 3
let only = arguments.first { !$0.hasPrefix("--") }?.uppercased()

let model = SystemLanguageModel.default
guard case .available = model.availability else {
    print("Apple Intelligence isn't available on this Mac: \(model.availability)")
    exit(1)
}

let variants = BounceRate.variants.filter { only == nil || only!.contains($0.id) }
print("Context window: \(model.contextSize) tokens. Running \(variants.map(\.id).joined()) × \(runs).\n")

let results = await Lab.run(variants, attempts: runs, truth: BounceRate.truth)

let notes = """
    Planted story: 5,200 supporters imported Sep 1–7; the next send ("Welcome, new friends", Sep 8) \
    hard-bounced at 3.29% and drew many spam complaints; soft bounces crept up across most later sends.
    "Unsupported numbers" are figures in the answer that are neither in the input nor a correct calculation.
    """
/// Did the answer find the planted story? Plain text search, so read the answers too.
let checks: [Lab.Check] = [
    ("Names the Sep 8 send", { text in
        text.contains("Welcome, new friends") || text.contains(#/(?i)sep(tember)?\.? 8\b|8 sep/#) ? "yes" : "no"
    }),
    // Whole words only: "important" isn't a mention.
    ("Mentions the import", { text in text.contains(#/(?i)\bimport(s|ed|ing)?\b/#) ? "yes" : "no" }),
    ("Isolated or systemic", { text in
        let lower = text.lowercased()
        let isolated = ["isolated", "one send", "single send"].contains { lower.contains($0) }
        let systemic = ["systemic", "broader problem", "across all"].contains { lower.contains($0) }
        return isolated && systemic ? "both" : isolated ? "isolated" : systemic ? "systemic" : "–"
    }),
]
let report = Lab.report(results, experiment: "Email bounce rate", contextSize: model.contextSize, notes: notes, checks: checks)

let folder = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "Results")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)
    .dateSeparator(.dash).timeSeparator(.omitted).dateTimeSeparator(.standard))
let file = folder.appending(path: "bounce-rate-\(stamp).md")
try report.write(to: file, atomically: true, encoding: .utf8)
print("\nReport: \(file.path)")
