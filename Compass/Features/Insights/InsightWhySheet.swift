//
//  InsightWhySheet.swift
//  Compass
//
//  "Why?" on an insight: the figures behind it and how Compass picked it.
//  Plain facts only, so it works the same with or without Apple Intelligence.
//

import SwiftUI

struct InsightWhySheet: View {
    let insight: Insight
    let facts: [Fact]

    @Environment(\.dismiss) private var dismiss

    private var cited: [Fact] {
        insight.factIDs.compactMap { id in facts.first { $0.id == id } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(insight.title)
                        .font(.system(.title2, design: .serif, weight: .bold))

                    section("What it’s based on") {
                        VStack(spacing: 0) {
                            ForEach(cited) { fact in
                                FactRow(fact: fact)
                                if fact.id != cited.last?.id {
                                    Divider().overlay(Color.compassDivider)
                                }
                            }
                        }
                        .compassCard()
                    }

                    section("How Compass chose it") {
                        Text(method)
                            .font(.subheadline)
                    }

                    section("Who wrote it") {
                        Text(insight.isGenerated
                             ? "Apple Intelligence wrote the words on this iPhone. The figures come straight from Engaging Networks, worked out by Compass."
                             : "Compass wrote this from your figures on this iPhone. The figures come straight from Engaging Networks.")
                            .font(.subheadline)
                    }
                }
                .padding(20)
            }
            .background(Color.compassBackground)
            .foregroundStyle(Color.compassText)
            .navigationTitle("Why?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// Worded from InsightRules' thresholds so the explanation can't drift from the rule.
    private var method: String {
        let percent = Int(InsightRules.minimumScore)
        let points = (InsightRules.minimumScore / InsightRules.pointsToPercent)
            .formatted(.number.precision(.fractionLength(0...1)))
        let base = "Compass compares the 7 complete days ending yesterday with the 7 days before those."
        if insight.severity == .neutral {
            return "\(base) None of these moved by \(percent)% or more (\(points) points for email opens), so they count as steady."
        }
        return "\(base) A change of \(percent)% or more (\(points) points for email opens) is worth a closer look, and bigger changes come first."
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.compassSecondaryText)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

private struct FactRow: View {
    let fact: Fact

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(fact.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let change = fact.change {
                    ChangeBadge(change: change)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                figure(fact.formattedValue, label: fact.metric == .supporters ? "Now" : "Last 7 days")
                Spacer()
                if let baseline = fact.formattedBaseline {
                    figure(baseline, label: fact.metric == .supporters ? "7 days ago" : "The 7 days before")
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func figure(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.compassSecondaryText)
        }
    }
}
