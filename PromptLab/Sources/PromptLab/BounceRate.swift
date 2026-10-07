//
//  BounceRate.swift
//  PromptLab
//
//  Experiment: an analyst-style deliverability prompt on the on-device model.
//
//  The fake data has one planted story, so we can tell whether the model finds it:
//  5,200 supporters were imported in early September; the next send ("Welcome, new
//  friends", Sep 8) hard-bounced at over 3% and drew many spam complaints. Soft bounces
//  also crept up across most later sends. A good answer calls the hard-bounce problem
//  mostly isolated (one send, after an import) and the soft-bounce rise small but broad.
//
//  Only fields Engaging Networks really has are used: EaBroadcastInfo (per send),
//  BroadcastMessageAttribute (email type) and AccountReports newjoins (imports).
//

import Foundation
import FoundationModels

/// One email send, as EaBroadcastInfo returns it, plus its type from BroadcastMessageAttribute.
struct Broadcast {
    let date: String
    let name: String
    let type: String
    let sent: Int
    let hard: Int
    let soft: Int
    let opens: Int
    let clicks: Int
    let unsubscribes: Int
    /// EN's feedbackCount: people who marked it as spam.
    let complaints: Int

    var totals: EmailTotals { EmailTotals([self]) }
}

/// Totals and rates for a group of sends. Bounce and delivery rates are of emails sent;
/// engagement rates are of emails delivered. Rates are in percent.
struct EmailTotals {
    var sends = 0, sent = 0, hard = 0, soft = 0, opens = 0, clicks = 0, unsubscribes = 0, complaints = 0

    init(_ broadcasts: [Broadcast]) {
        for b in broadcasts {
            sends += 1; sent += b.sent; hard += b.hard; soft += b.soft; opens += b.opens
            clicks += b.clicks; unsubscribes += b.unsubscribes; complaints += b.complaints
        }
    }

    var bounced: Int { hard + soft }
    var delivered: Int { sent - bounced }
    var bounceRate: Double { percent(bounced, of: sent) }
    var hardRate: Double { percent(hard, of: sent) }
    var softRate: Double { percent(soft, of: sent) }
    var deliveryRate: Double { percent(delivered, of: sent) }
    var openRate: Double { percent(opens, of: delivered) }
    var clickRate: Double { percent(clicks, of: delivered) }
    var clickToOpenRate: Double { percent(clicks, of: opens) }
    var unsubscribeRate: Double { percent(unsubscribes, of: delivered) }
    var complaintRate: Double { percent(complaints, of: delivered) }
    var averagePerSend: Int { sends == 0 ? 0 : sent / sends }

    private func percent(_ part: Int, of whole: Int) -> Double {
        whole == 0 ? 0 : Double(part) / Double(whole) * 100
    }
}

enum BounceRate {
    // MARK: Fake data

    static let lastThirtyDays = [
        Broadcast(date: "Aug 27, 2026", name: "August newsletter", type: "Newsletter", sent: 46_200, hard: 92, soft: 520, opens: 16_170, clicks: 1_270, unsubscribes: 60, complaints: 7),
        Broadcast(date: "Aug 31, 2026", name: "Clean Water petition push", type: "Advocacy", sent: 45_900, hard: 87, soft: 540, opens: 15_600, clicks: 2_110, unsubscribes: 55, complaints: 6),
        Broadcast(date: "Sep 3, 2026", name: "Fall Appeal – launch", type: "Appeal", sent: 47_100, hard: 101, soft: 560, opens: 16_020, clicks: 1_410, unsubscribes: 64, complaints: 8),
        Broadcast(date: "Sep 8, 2026", name: "Welcome, new friends", type: "Newsletter", sent: 52_300, hard: 1_720, soft: 780, opens: 14_650, clicks: 980, unsubscribes: 310, complaints: 61),
        Broadcast(date: "Sep 11, 2026", name: "Fall Appeal – reminder", type: "Appeal", sent: 50_900, hard: 240, soft: 700, opens: 15_780, clicks: 1_120, unsubscribes: 140, complaints: 22),
        Broadcast(date: "Sep 15, 2026", name: "Letter to the Governor", type: "Advocacy", sent: 50_400, hard: 150, soft: 690, opens: 16_130, clicks: 2_420, unsubscribes: 95, complaints: 12),
        Broadcast(date: "Sep 17, 2026", name: "Fall Appeal – matching gift", type: "Appeal", sent: 50_200, hard: 120, soft: 700, opens: 15_560, clicks: 1_300, unsubscribes: 88, complaints: 11),
        Broadcast(date: "Sep 20, 2026", name: "Volunteer survey", type: "Newsletter", sent: 49_800, hard: 105, soft: 690, opens: 15_440, clicks: 890, unsubscribes: 70, complaints: 9),
        Broadcast(date: "Sep 22, 2026", name: "Fall Appeal – final hours", type: "Appeal", sent: 50_100, hard: 110, soft: 720, opens: 16_030, clicks: 1_450, unsubscribes: 80, complaints: 10),
    ]

    static let sameTimeLastYear = [
        Broadcast(date: "Aug 26, 2025", name: "August newsletter", type: "Newsletter", sent: 41_800, hard: 71, soft: 450, opens: 15_050, clicks: 1_250, unsubscribes: 52, complaints: 5),
        Broadcast(date: "Aug 29, 2025", name: "Summer action alert", type: "Advocacy", sent: 41_900, hard: 80, soft: 470, opens: 14_700, clicks: 2_050, unsubscribes: 50, complaints: 6),
        Broadcast(date: "Sep 2, 2025", name: "Fall Appeal 2025 – launch", type: "Appeal", sent: 42_300, hard: 76, soft: 480, opens: 15_230, clicks: 1_390, unsubscribes: 58, complaints: 7),
        Broadcast(date: "Sep 6, 2025", name: "Stories from the field", type: "Newsletter", sent: 42_100, hard: 68, soft: 455, opens: 14_950, clicks: 1_020, unsubscribes: 49, complaints: 5),
        Broadcast(date: "Sep 10, 2025", name: "Fall Appeal 2025 – reminder", type: "Appeal", sent: 42_400, hard: 81, soft: 470, opens: 14_840, clicks: 1_180, unsubscribes: 61, complaints: 6),
        Broadcast(date: "Sep 14, 2025", name: "Petition delivery update", type: "Advocacy", sent: 42_600, hard: 72, soft: 468, opens: 15_340, clicks: 1_960, unsubscribes: 47, complaints: 5),
        Broadcast(date: "Sep 18, 2025", name: "Fall Appeal 2025 – match", type: "Appeal", sent: 42_700, hard: 79, soft: 485, opens: 14_950, clicks: 1_300, unsubscribes: 60, complaints: 7),
        Broadcast(date: "Sep 22, 2025", name: "Fall Appeal 2025 – final", type: "Appeal", sent: 42_800, hard: 77, soft: 490, opens: 15_410, clicks: 1_480, unsubscribes: 57, complaints: 6),
    ]

    static let supportersNow = 58_420
    static let newJoins = (total: 7_030, imported: 5_200, donation: 520, advocacy: 1_310)
    static let newJoinsLastYear = (total: 1_610, imported: 0, donation: 430, advocacy: 1_180)

    // MARK: The prompt as given

    static let analystPrompt = """
        Analyze email deliverability for last 30 days compared with same period last year. Focus on total bounce rate, hard bounces, soft bounces, delivery rate, unsubscribes, spam complaints, and engagement after delivery. Break results down by email type, audience segment, sending domain, list source, campaign, and send volume where available.
        Provide:
        1. A clear diagnosis of the biggest deliverability issues and whether they appear isolated or systemic.
        2. The likely causes, separating evidence from hypotheses.
        3. A prioritized remediation plan for the next 30 days, including list hygiene, sender reputation, authentication, segmentation, cadence, and content/testing actions where relevant.
        4. Specific thresholds or metrics to monitor weekly and conditions that should trigger escalation.
        5. Any data needed to confirm the diagnosis.
        """

    static let diagnosisOnlyPrompt = """
        Compare email deliverability in the last 30 days with the same period last year. \
        What is the biggest deliverability issue, and is it isolated (one or a few sends) or systemic (most sends)? \
        Name the sends involved and cite the figures. Answer in at most five sentences.
        """

    static let analystInstructions = "You are an email deliverability analyst. You help a nonprofit understand its email results."

    static let onlyTheseFigures = """
        \(analystInstructions)
        Use only the figures in the data. If something isn't in the data, say it isn't available; never estimate it or assume a value.
        """

    // MARK: Data blocks

    /// What EN returns, with nothing worked out: the model has to do the maths.
    static var rawData: String {
        func line(_ b: Broadcast) -> String {
            "- \(b.date) | \(b.name) | \(b.type) | \(n(b.sent)) | \(n(b.hard)) | \(n(b.soft)) | \(n(b.opens)) | \(n(b.clicks)) | \(n(b.unsubscribes)) | \(n(b.complaints))"
        }
        let columns = "date | name | email type | emails sent | hard bounces | soft bounces | opens | clicks | unsubscribes | spam complaints"
        return """
            Sends in the last 30 days (Aug 25 – Sep 23, 2026). Columns: \(columns)
            \(lastThirtyDays.map(line).joined(separator: "\n"))

            Sends in the same period last year (Aug 25 – Sep 23, 2025). Same columns.
            \(sameTimeLastYear.map(line).joined(separator: "\n"))

            \(supporterLines)
            """
    }

    /// Everything Swift can work out: per-send rates, totals with changes, by email type.
    static var precomputedData: String {
        func line(_ b: Broadcast) -> String {
            let t = b.totals
            return "- \(b.date) | \(b.name) | \(b.type) | sent \(n(b.sent)) | delivered \(pct(t.deliveryRate)) | "
                + "hard bounce \(pct(t.hardRate)) | soft bounce \(pct(t.softRate)) | open \(pct(t.openRate)) | "
                + "click \(pct(t.clickRate)) | unsubscribe \(pct(t.unsubscribeRate)) | spam complaint \(pct(t.complaintRate, 3))"
        }
        return """
            Totals: last 30 days (Aug 25 – Sep 23, 2026) vs the same period last year (Aug 25 – Sep 23, 2025).
            \(totalsTable)

            By email type (last 30 days vs same period last year):
            \(byType)

            Each send in the last 30 days:
            \(lastThirtyDays.map(line).joined(separator: "\n"))

            Each send in the same period last year:
            \(sameTimeLastYear.map(line).joined(separator: "\n"))

            \(supporterLines)
            """
    }

    static let notAvailable = """
        Not available (Engaging Networks doesn't provide it): bounce reasons, recipient domains or mailbox providers, \
        sending domain, SPF/DKIM/DMARC status, audience segments, list source of each send, suppression list size, \
        inactive subscriber counts, changes to platform or templates, and the supporter count a year ago.
        """

    private static var supporterLines: String {
        """
        New supporters in the last 30 days: \(n(newJoins.total)) (\(n(newJoins.imported)) imported, \(n(newJoins.donation)) from donation pages, \(n(newJoins.advocacy)) from advocacy pages). The \(n(newJoins.imported)) imported supporters were added between Sep 1 and Sep 7, 2026.
        New supporters in the same period last year: \(n(newJoinsLastYear.total)) (\(n(newJoinsLastYear.imported)) imported, \(n(newJoinsLastYear.donation)) from donation pages, \(n(newJoinsLastYear.advocacy)) from advocacy pages).
        Supporters now: \(n(supportersNow)).
        """
    }

    private static var totalsTable: String {
        let now = EmailTotals(lastThirtyDays), then = EmailTotals(sameTimeLastYear)
        func count(_ name: String, _ a: Int, _ b: Int) -> String {
            "- \(name): \(n(a)) vs \(n(b)) (\(change(Double(a), Double(b))))"
        }
        func rate(_ name: String, _ a: Double, _ b: Double, _ digits: Int = 2) -> String {
            "- \(name): \(pct(a, digits)) vs \(pct(b, digits)) (\(points(a - b, digits)))"
        }
        return [
            count("Sends", now.sends, then.sends),
            count("Emails sent", now.sent, then.sent),
            count("Average emails per send", now.averagePerSend, then.averagePerSend),
            count("Delivered", now.delivered, then.delivered),
            rate("Delivery rate", now.deliveryRate, then.deliveryRate),
            count("Bounces", now.bounced, then.bounced),
            rate("Total bounce rate", now.bounceRate, then.bounceRate),
            count("Hard bounces", now.hard, then.hard),
            rate("Hard bounce rate", now.hardRate, then.hardRate),
            count("Soft bounces", now.soft, then.soft),
            rate("Soft bounce rate", now.softRate, then.softRate),
            rate("Open rate", now.openRate, then.openRate),
            rate("Click rate", now.clickRate, then.clickRate),
            rate("Click-to-open rate", now.clickToOpenRate, then.clickToOpenRate),
            rate("Unsubscribe rate", now.unsubscribeRate, then.unsubscribeRate),
            rate("Spam complaint rate", now.complaintRate, then.complaintRate, 3),
        ].joined(separator: "\n")
    }

    private static var byType: String {
        ["Appeal", "Newsletter", "Advocacy"].map { type in
            let now = EmailTotals(lastThirtyDays.filter { $0.type == type })
            let then = EmailTotals(sameTimeLastYear.filter { $0.type == type })
            return "- \(type): \(now.sends) sends vs \(then.sends) | hard bounce \(pct(now.hardRate)) vs \(pct(then.hardRate)) | "
                + "soft bounce \(pct(now.softRate)) vs \(pct(then.softRate)) | spam complaint \(pct(now.complaintRate, 3)) vs \(pct(then.complaintRate, 3)) | "
                + "unsubscribe \(pct(now.unsubscribeRate)) vs \(pct(then.unsubscribeRate))"
        }.joined(separator: "\n")
    }

    // MARK: Swift's own analysis (variant E)

    /// The spike send: hard bounce rate over 1% and at least three times the period's median.
    static var spike: Broadcast? {
        let rates = lastThirtyDays.map(\.totals.hardRate).sorted()
        let median = rates[rates.count / 2]
        return lastThirtyDays.max { $0.totals.hardRate < $1.totals.hardRate }
            .flatMap { $0.totals.hardRate > 1 && $0.totals.hardRate >= median * 3 ? $0 : nil }
    }

    /// Findings with IDs, the way the app would hand them to the model.
    static var findings: String {
        let now = EmailTotals(lastThirtyDays), then = EmailTotals(sameTimeLastYear)
        guard let spike else { return "No findings." }
        let others = EmailTotals(lastThirtyDays.filter { $0.name != spike.name })
        let share = Double(spike.hard) / Double(now.hard) * 100
        let highestSoftLastYear = sameTimeLastYear.map(\.totals.softRate).max() ?? 0
        let softAbove = lastThirtyDays.filter { $0.totals.softRate > highestSoftLastYear }.count
        return """
            F1 (needs attention): Hard bounces rose. Hard bounce rate \(pct(now.hardRate)) in the last 30 days, \(pct(then.hardRate)) in the same period last year.
            F2 (needs attention): Most of the rise comes from one send. "\(spike.name)" (\(spike.date)) had a hard bounce rate of \(pct(spike.totals.hardRate)) and caused \(pct(share, 0)) of all hard bounces in the period. Without it, the hard bounce rate was \(pct(others.hardRate)).
            F3: \(n(newJoins.imported)) supporters were imported between Sep 1 and Sep 7, just before that send. None were imported in the same period last year.
            F4 (needs attention): Spam complaints on that send were \(pct(spike.totals.complaintRate, 3)), against \(pct(others.complaintRate, 3)) on the other sends.
            F5 (needs attention): Soft bounces rose a little across most sends: \(pct(now.softRate)) against \(pct(then.softRate)) last year. \(softAbove) of \(now.sends) sends were above last year's highest.
            Scope: mostly isolated. One send after an import caused most hard bounces; soft bounces rose a little across most sends.
            """
    }

    /// Weekly checks and missing data: fixed app rules, no model involved.
    static let swiftWrittenSections = """
        **Watch every week (app rules, no model):**
        - Hard bounce rate per send: needs attention above 0.5%; pause and review the audience above 2%.
        - Spam complaint rate per send: needs attention above 0.1%; escalate above 0.3% (Google and Yahoo's limit for bulk senders).
        - Soft bounce rate per send: needs attention if above last year's highest for three sends in a row.
        - Delivery rate: escalate below 97%.

        **What would confirm this (not in the Engaging Networks data service):** bounce reasons for the \
        "Welcome, new friends" send, where the imported list came from and when those people signed up, \
        and whether soft bounces are concentrated at one mailbox provider.
        """

    /// Correct figures the model wasn't necessarily given, to recognise its own correct maths.
    static var truth: String {
        let now = EmailTotals(lastThirtyDays), then = EmailTotals(sameTimeLastYear)
        let all = lastThirtyDays + sameTimeLastYear
        var extra: [String] = [precomputedData, findings]
        for b in all {
            let t = b.totals
            extra.append("\(t.bounceRate) \(t.bounced) \(t.delivered) \(t.clickToOpenRate)")
        }
        let pairs: [(Double, Double)] = [
            (Double(now.sent), Double(then.sent)), (Double(now.hard), Double(then.hard)), (Double(now.soft), Double(then.soft)),
            (now.hardRate, then.hardRate), (now.softRate, then.softRate), (now.bounceRate, then.bounceRate),
            (now.complaintRate, then.complaintRate), (now.unsubscribeRate, then.unsubscribeRate),
            (Double(now.complaints), Double(then.complaints)), (Double(now.unsubscribes), Double(then.unsubscribes)),
            (Double(newJoins.total), Double(newJoinsLastYear.total)),
        ]
        for (a, b) in pairs {
            extra.append("\(abs((a - b) / b * 100)) \(abs(a - b)) \(a / b)")
        }
        extra.append("\(now.complaints) \(now.unsubscribes) \(then.complaints) \(then.unsubscribes) \(now.opens) \(now.clicks)")
        return extra.joined(separator: "\n")
    }

    // MARK: Variants

    static var variants: [Variant] {
        let ask: (LanguageModelSession, String) async throws -> String = { session, prompt in
            try await session.respond(to: prompt).content
        }
        return [
            Variant(id: "A", title: "The prompt as written, raw EN counts (the model does the maths)",
                    instructions: analystInstructions,
                    prompt: analystPrompt + "\n\nData:\n" + rawData,
                    schema: nil, ask: ask),
            Variant(id: "B", title: "The prompt as written, rates and changes precomputed by Swift",
                    instructions: analystInstructions,
                    prompt: analystPrompt + "\n\nData:\n" + precomputedData,
                    schema: nil, ask: ask),
            Variant(id: "C", title: "B, plus the list of what's not available and \"use only these figures\"",
                    instructions: onlyTheseFigures,
                    prompt: analystPrompt + "\n\nData:\n" + precomputedData + "\n\n" + notAvailable,
                    schema: nil, ask: ask),
            Variant(id: "D", title: "C, answered in a fixed structure (guided generation)",
                    instructions: onlyTheseFigures,
                    prompt: analystPrompt + "\n\nData:\n" + precomputedData + "\n\n" + notAvailable,
                    schema: DeliverabilityReport.generationSchema,
                    ask: { session, prompt in
                        try await session.respond(to: prompt, generating: DeliverabilityReport.self).content.rendered
                    }),
            Variant(id: "F", title: "C's data, but only question 1 (the diagnosis): is it the prompt's size or the reasoning?",
                    instructions: onlyTheseFigures,
                    prompt: diagnosisOnlyPrompt + "\n\nData:\n" + precomputedData + "\n\n" + notAvailable,
                    schema: nil, ask: ask),
            Variant(id: "E", title: "Swift diagnoses; the model only words its findings (the app's pattern)",
                    instructions: briefInstructions,
                    prompt: "Findings (worked out by the app):\n" + findings,
                    schema: DeliverabilityBrief.generationSchema,
                    ask: { session, prompt in
                        try await session.respond(to: prompt, generating: DeliverabilityBrief.self).content.rendered
                    },
                    appendix: swiftWrittenSections),
        ]
    }

    static let briefInstructions = """
        You write a short email deliverability summary for nonprofit staff who are not email experts. \
        The app has already analysed the numbers; you put its findings into plain words.
        - Use only the findings given. Don't add causes, figures, benchmarks or facts that aren't in them.
        - Never write digits, amounts or percentages. The app shows the figures next to your words.
        - Word possible causes as possibilities ("may", "might"), never as facts.
        - Speak to the reader as "you".
        """

    // MARK: Formatting

    private static let locale = Locale(identifier: "en_US")
    static func n(_ value: Int) -> String { value.formatted(.number.locale(locale)) }
    static func pct(_ value: Double, _ digits: Int = 2) -> String { String(format: "%.\(digits)f%%", value) }
    static func points(_ value: Double, _ digits: Int = 2) -> String { String(format: "%+.\(digits)f pts", value) }
    static func change(_ a: Double, _ b: Double) -> String {
        b == 0 ? "new" : String(format: "%+.1f%%", (a - b) / b * 100)
    }
}

// MARK: - Output structures

@Generable
struct DeliverabilityReport {
    @Guide(description: "The biggest deliverability issues, in two or three sentences")
    var diagnosis: String
    @Guide(description: "Whether the issues are limited to a few sends or affect most sends",
           .anyOf(["isolated", "mostly isolated", "systemic"]))
    var scope: String
    @Guide(description: "Findings the data shows directly, each citing its figures", .maximumCount(5))
    var evidence: [String]
    @Guide(description: "Possible causes the data does not prove", .maximumCount(4))
    var hypotheses: [String]
    @Guide(description: "Actions for the next 30 days, most important first", .maximumCount(6))
    var plan: [PlanStep]
    @Guide(description: "Metrics to watch each week and the level that should trigger escalation", .maximumCount(5))
    var monitoring: [Threshold]
    @Guide(description: "Data that would confirm the diagnosis", .maximumCount(5))
    var dataNeeded: [String]

    var rendered: String {
        """
        **Diagnosis** (scope: \(scope)): \(diagnosis)

        **Evidence:**
        \(evidence.map { "- \($0)" }.joined(separator: "\n"))

        **Hypotheses:**
        \(hypotheses.map { "- \($0)" }.joined(separator: "\n"))

        **Plan:**
        \(plan.enumerated().map { "\($0.offset + 1). [\($0.element.area)] \($0.element.action)" }.joined(separator: "\n"))

        **Monitor weekly:**
        \(monitoring.map { "- \($0.metric): escalate when \($0.escalateWhen)" }.joined(separator: "\n"))

        **Data needed:**
        \(dataNeeded.map { "- \($0)" }.joined(separator: "\n"))
        """
    }
}

@Generable
struct PlanStep {
    @Guide(.anyOf(["list hygiene", "sender reputation", "authentication", "segmentation", "cadence", "content and testing"]))
    var area: String
    @Guide(description: "One specific action")
    var action: String
}

@Generable
struct Threshold {
    var metric: String
    @Guide(description: "The condition that should trigger escalation")
    var escalateWhen: String
}

@Generable
struct DeliverabilityBrief {
    @Guide(description: "A headline of at most ten words, with no numbers")
    var headline: String
    @Guide(description: "Two or three sentences: the biggest problem, and whether it is limited to one send or affects most sends")
    var diagnosis: String
    @Guide(description: "Possible causes, each tied to the findings that support it", .maximumCount(3))
    var likelyCauses: [LikelyCause]

    var rendered: String {
        """
        **\(headline)**

        \(diagnosis)

        **Likely causes (model):**
        \(likelyCauses.map { "- \($0.cause) _(from \($0.findingIDs.joined(separator: ", ")))_" }.joined(separator: "\n"))
        """
    }
}

@Generable
struct LikelyCause {
    @Guide(description: "IDs of the findings that support this cause, copied exactly, like F2")
    var findingIDs: [String]
    @Guide(description: "One sentence naming a possible cause, worded as a possibility, with no numbers")
    var cause: String
}
