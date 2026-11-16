//
//  InsightsView.swift
//  Compass
//
//  Insights tab: the digest of what changed in the numbers.
//

import SwiftData
import SwiftUI

struct InsightsView: View {
    let pulse: PulseViewModel

    @State private var model = InsightsViewModel()
    @State private var whyInsight: Insight?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                privacyNote
                if pulse.refreshFailed {
                    refreshFailedBanner
                }
                digest
                if model.aiStatus == .turnedOff, !model.facts.isEmpty {
                    Text("Turn on Apple Intelligence in Settings to have it write your insights.")
                        .font(.footnote)
                        .foregroundStyle(Color.compassSecondaryText)
                } else if model.aiStatus == .gettingReady, !model.facts.isEmpty {
                    Text("Apple Intelligence is still getting ready on this iPhone. Once it’s ready, it will write your insights.")
                        .font(.footnote)
                        .foregroundStyle(Color.compassSecondaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.compassBackground)
        .foregroundStyle(Color.compassText)
        .refreshable { await pulse.refresh(in: modelContext) }
        .task { await pulse.refreshIfStale(in: modelContext) }
        .task(id: pulse.allFacts) { await model.update(facts: pulse.allFacts) }
        .sheet(item: $whyInsight) { insight in
            InsightWhySheet(insight: insight, facts: model.facts)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(pulse.shownPeriod.title) · \(pulse.period.label)")
                .font(.subheadline)
                .foregroundStyle(Color.compassSecondaryText)
            Text("Insights")
                .font(.compassScreenTitle)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, 8)
    }

    private var privacyNote: some View {
        Label {
            Text(model.author == .appleIntelligence
                 ? "Written on this iPhone with Apple Intelligence. Your data never leaves the device."
                 : "Written on this iPhone from your numbers. Your data never leaves the device.")
        } icon: {
            Image(systemName: "lock")
        }
        .font(.footnote)
        .foregroundStyle(Color.compassSecondaryText)
    }

    private var refreshFailedBanner: some View {
        Label("Couldn’t reach Engaging Networks. Pull down to try again.", systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.compassOrangeTint, in: .rect(cornerRadius: 16))
    }

    // MARK: Digest

    @ViewBuilder
    private var digest: some View {
        if !model.insights.isEmpty {
            if model.isWriting {
                // The cards below are the templates until Apple Intelligence rewrites each one.
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Apple Intelligence is writing your digest…")
                        .font(.footnote)
                        .foregroundStyle(Color.compassSecondaryText)
                }
                .accessibilityElement(children: .combine)
            }
            ForEach(model.insights) { insight in
                InsightCard(insight: insight, facts: model.facts) { whyInsight = insight }
            }
        } else if pulse.isRefreshing {
            ProgressView("Loading your numbers…")
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            ContentUnavailableView(
                "No insights yet",
                systemImage: "sparkles",
                description: Text("Pull down to load your numbers.")
            )
        }
    }
}

// MARK: - Cards

private struct InsightCard: View {
    let insight: Insight
    let facts: [Fact]
    var onWhy: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SeverityChip(severity: insight.severity)
            Text(insight.title)
                .font(.system(.title3, design: .serif, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text(insight.explanation)
                .font(.subheadline)
            FigureChips(figures: InsightFigure.figures(for: insight.factIDs, in: facts))

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .bottom, spacing: 12))
            layout {
                if let action = insight.suggestedAction {
                    Text("\(Text("Try this:").bold().foregroundStyle(Color.compassText)) \(action)")
                        .font(.subheadline)
                        .foregroundStyle(Color.compassSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer(minLength: 0)
                }
                Button("Why?", action: onWhy)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.compassTeal)
                    .frame(minWidth: 44, minHeight: 44)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Why: \(insight.title)")
            }
            .padding(.bottom, -8)
        }
        .compassCard()
    }
}

/// "Needs attention", "Opportunity", "Good news" or "Steady", with an icon so
/// meaning never rests on color alone.
private struct SeverityChip: View {
    let severity: Insight.Severity

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .background(background, in: .capsule)
    }

    private var title: String {
        switch severity {
        case .attention: "Needs attention"
        case .opportunity: "Opportunity"
        case .good: "Good news"
        case .neutral: "Steady"
        }
    }

    private var systemImage: String {
        switch severity {
        case .attention: "exclamationmark.triangle"
        case .opportunity: "sparkles"
        case .good: "checkmark"
        case .neutral: "equal"
        }
    }

    private var foreground: Color {
        switch severity {
        case .attention: .compassOrange
        case .opportunity: .compassTeal
        case .good, .neutral: .compassText
        }
    }

    private var background: Color {
        switch severity {
        case .attention: .compassOrangeTint
        case .opportunity: .compassTealTint
        case .good, .neutral: .compassNeutralTint
        }
    }
}

/// "386 last 7 days" chips. Figures come from facts, never from generated text.
private struct FigureChips: View {
    let figures: [InsightFigure]

    var body: some View {
        if !figures.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(figures, id: \.self) { figure in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(figure.value)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.compassText)
                        Text(figure.label)
                            .font(.footnote)
                            .foregroundStyle(Color.compassSecondaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.compassBackground, in: .rect(cornerRadius: 10))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

#Preview {
    InsightsView(pulse: PulseViewModel(credentials: ENCredentials(region: .test, token: "1")))
        .modelContainer(for: [FollowedPage.self, SupporterSnapshot.self], inMemory: true)
}
