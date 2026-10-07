//
//  PulseView.swift
//  Compass
//
//  Home tab: "how have the last 7 days gone?"
//

import Charts
import SwiftData
import SwiftUI

struct PulseView: View {
    let model: PulseViewModel
    var onSeeAllInsights: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var heroNumberSize: CGFloat = 44

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if model.refreshFailed {
                    refreshFailedBanner
                }
                if model.hasData {
                    if let supporters = model.supporters {
                        supportersCard(supporters)
                    }
                    tiles
                    if let insight = model.topInsight {
                        insightCard(insight)
                    }
                } else if model.isRefreshing {
                    ProgressView("Loading your numbers…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.compassBackground)
        .foregroundStyle(Color.compassText)
        .refreshable { await model.refresh(in: modelContext) }
        .task { await model.refreshIfStale(in: modelContext) }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.compassSecondaryText)
                Text("Pulse")
                    .font(.compassScreenTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Button {
                Task { await model.refresh(in: modelContext) }
            } label: {
                Group {
                    if model.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .fontWeight(.medium)
                    }
                }
                .frame(width: 44, height: 44)
                .background(Color.compassCard, in: .circle)
                .shadow(color: Color.compassText.opacity(0.08), radius: 1, y: 1)
            }
            .buttonStyle(.plain)
            .disabled(model.isRefreshing)
            .accessibilityLabel(model.isRefreshing ? "Refreshing" : "Refresh")
        }
        .padding(.top, 8)
    }

    private var refreshFailedBanner: some View {
        Label("Couldn’t reach Engaging Networks. Pull down to try again.", systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .foregroundStyle(Color.compassText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.compassOrangeTint, in: .rect(cornerRadius: 16))
    }

    // MARK: Supporters

    private func supportersCard(_ fact: Fact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Supporters")
                    .font(.subheadline)
                    .foregroundStyle(Color.compassSecondaryText)
                Spacer()
                if let change = fact.change {
                    ChangeBadge(change: change, suffix: " in the last 7 days")
                }
            }
            Text(fact.formattedValue)
                .font(.system(size: heroNumberSize, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if model.supporterTrend.count >= 2 {
                SupporterSparkline(points: model.supporterTrend)
                    .frame(height: 56)
                HStack {
                    Text(trendStartLabel)
                    Spacer()
                    Text("Now")
                }
                .font(.caption)
                .foregroundStyle(Color.compassSecondaryText)
                .accessibilityHidden(true)
            } else {
                Text("Compass saves this number each day it refreshes, so your trend line will build over the coming weeks.")
                    .font(.footnote)
                    .foregroundStyle(Color.compassSecondaryText)
            }
        }
        .compassCard()
    }

    private var trendStartLabel: String {
        guard let first = model.supporterTrend.first, let last = model.supporterTrend.last else { return "" }
        let weeks = Int((last.date.timeIntervalSince(first.date) / (7 * 86_400)).rounded())
        return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
    }

    // MARK: Weekly tiles

    private var tiles: some View {
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columns),
                         spacing: 12) {
            ForEach(model.weeklyFacts) { fact in
                MetricTile(fact: fact)
            }
        }
    }

    // MARK: Insight

    private func insightCard(_ insight: Insight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Top insight", systemImage: "sparkles")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.compassTeal)
                Spacer()
                Label("On-device", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(Color.compassSecondaryText)
            }
            Text(insight.title)
                .font(.system(.title3, design: .serif, weight: .bold))
            Text(insight.explanation)
                .font(.subheadline)
            if let action = insight.suggestedAction {
                Text("\(Text("Try this:").bold().foregroundStyle(Color.compassText)) \(action)")
                    .font(.subheadline)
                    .foregroundStyle(Color.compassSecondaryText)
            }
            Button(action: onSeeAllInsights) {
                HStack(spacing: 2) {
                    Text("See all insights")
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.compassTeal)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.bottom, -8)
        }
        .compassCard()
    }
}

// MARK: - Pieces

private struct MetricTile: View {
    let fact: Fact

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(fact.displayName)
                .font(.subheadline)
                .foregroundStyle(Color.compassSecondaryText)
            Text(fact.formattedValue)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let change = fact.change {
                ChangeBadge(change: change)
                Text("vs previous 7 days")
                    .font(.caption)
                    .foregroundStyle(Color.compassSecondaryText)
            } else {
                Text("Last 7 days")
                    .font(.caption)
                    .foregroundStyle(Color.compassSecondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.compassCard, in: .rect(cornerRadius: 20))
        .shadow(color: Color.compassText.opacity(0.06), radius: 1, y: 1)
        .accessibilityElement(children: .combine)
    }
}

private struct SupporterSparkline: View {
    let points: [SupporterTrend.Point]

    var body: some View {
        let counts = points.map(\.count)
        let low = counts.min() ?? 0
        let high = max(counts.max() ?? 0, low + 1)

        Chart(points, id: \.date) { point in
            AreaMark(
                x: .value("Week", point.date),
                yStart: .value("Floor", low),
                yEnd: .value("Supporters", point.count)
            )
            .foregroundStyle(Color.compassTeal.opacity(0.10))
            LineMark(x: .value("Week", point.date), y: .value("Supporters", point.count))
                .foregroundStyle(Color.compassTeal)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: low...high)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Supporters trend")
        .accessibilityValue(summary)
    }

    /// e.g. "Grew from 45,860 to 48,312 over 12 weeks."
    private var summary: String {
        guard let first = points.first, let last = points.last else { return "" }
        let verb = last.count > first.count ? "Grew" : (last.count < first.count ? "Fell" : "Stayed at")
        if verb == "Stayed at" { return "Stayed at \(last.count.formatted())." }
        return "\(verb) from \(first.count.formatted()) to \(last.count.formatted())."
    }
}

#Preview {
    PulseView(model: PulseViewModel(credentials: ENCredentials(region: .test, token: "1"))) {}
        .modelContainer(for: [FollowedPage.self, SupporterSnapshot.self], inMemory: true)
}
