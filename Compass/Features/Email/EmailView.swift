//
//  EmailView.swift
//  Compass
//
//  Email tab: "are supporters reading our emails, and when should we send?"
//

import Charts
import SwiftUI

struct EmailView: View {
    let model: EmailViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let message = model.errorMessage {
                    errorBanner(message)
                }
                if model.hasLoaded {
                    if model.recentSends.isEmpty {
                        noSendsCard
                    } else {
                        if !model.rates.isEmpty {
                            ratesCard
                        }
                        if let fatigue = model.fatigue {
                            fatigueBanner(fatigue)
                        }
                        recentSendsCard
                        if let best = model.best {
                            bestDayCard(best)
                        }
                    }
                } else if model.isRefreshing {
                    ProgressView("Loading your emails…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.compassBackground)
        .foregroundStyle(Color.compassText)
        .refreshable { await model.refresh() }
        .task { await model.refreshIfStale() }
    }

    // MARK: Header and banners

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.hasLoaded ? model.subtitle : "Last \(EmailViewModel.windowDays) days")
                .font(.subheadline)
                .foregroundStyle(Color.compassSecondaryText)
            Text("Email")
                .font(.compassScreenTitle)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, 8)
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.compassOrangeTint, in: .rect(cornerRadius: 16))
    }

    private func fatigueBanner(_ fatigue: EmailStats.Fatigue) -> some View {
        Label {
            Text("\(Text("Unsubscribes are climbing.").bold()) Your last \(fatigue.sends) emails lost supporters at about \(fatigue.timesUsual) times your usual rate. Consider a short break, or a gentler ask, before the next send.")
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Color.compassOrange)
        }
        .font(.subheadline)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.compassOrangeTint, in: .rect(cornerRadius: 16))
    }

    // MARK: Rates

    private var ratesCard: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return VStack(alignment: .leading, spacing: 12) {
            layout {
                ForEach(Array(model.rates.enumerated()), id: \.element.id) { index, rate in
                    if index > 0, !dynamicTypeSize.isAccessibilitySize {
                        Divider()
                            .overlay(Color.compassDivider)
                    }
                    RateColumn(rate: rate)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Text("Compared with the \(EmailViewModel.windowDays) days before")
                .font(.caption)
                .foregroundStyle(Color.compassSecondaryText)
        }
        .compassCard()
    }

    // MARK: Recent sends

    private var recentSendsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent sends")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 8)
            ForEach(model.recentSends) { send in
                Rectangle()
                    .fill(Color.compassDivider)
                    .frame(height: 1)
                SendRow(send: send, hasHighUnsubscribes: model.hasHighUnsubscribes(send))
            }
        }
        .padding(.bottom, -8)
        .compassCard()
    }

    // MARK: Best day

    private func bestDayCard(_ best: EmailStats.WeekdayRate) -> some View {
        let dayName = Calendar.current.weekdaySymbols[best.weekday - 1]
        let rate = best.clickRate.map(EmailFormat.compactPercent) ?? ""
        return VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    bestDayTitle
                    Spacer()
                    bestDaySubtitle
                }
                VStack(alignment: .leading, spacing: 2) {
                    bestDayTitle
                    bestDaySubtitle
                }
            }
            WeekdayChart(days: model.weekdays, bestWeekday: best.weekday)
                .frame(height: 120)
            Text("Emails sent on a \(dayName) got your best click rate: \(rate) of them led to a click. Based on your sends in the last \(EmailViewModel.historyDays) days\(skippedDaysNote).")
                .font(.footnote)
                .foregroundStyle(Color.compassSecondaryText)
        }
        .compassCard()
    }

    /// "; days with fewer than 3 sends aren't shown", when some were left out of the chart.
    private var skippedDaysNote: String {
        let minimum = EmailStats.minimumSendsForBestDay
        let skipped = model.weekdays.contains { $0.sends > 0 && $0.sends < minimum }
        return skipped ? "; days with fewer than \(minimum) sends aren’t shown" : ""
    }

    private var bestDayTitle: some View {
        Text("Best day to send")
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    private var bestDaySubtitle: some View {
        Text("Click rate by day")
            .font(.footnote)
            .foregroundStyle(Color.compassSecondaryText)
    }

    // MARK: Nothing sent

    private var noSendsCard: some View {
        ContentUnavailableView(
            "No emails yet",
            systemImage: "envelope",
            description: Text("Nothing was sent in the last \(EmailViewModel.historyDays) days. Results show up here after your next email goes out.")
        )
        .compassCard()
    }
}

// MARK: - Pieces

private struct RateColumn: View {
    let rate: EmailRate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rate.title)
                .font(.footnote)
                .foregroundStyle(Color.compassSecondaryText)
                .accessibilityLabel(rate.spokenTitle)
            Text(rate.formattedValue)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let change = rate.change {
                ChangeBadge(change: change)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct SendRow: View {
    let send: ENBroadcast
    let hasHighUnsubscribes: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let totals = EmailStats.Totals([send])
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            VStack(alignment: .leading, spacing: 3) {
                Text(send.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text("\(send.sentOn.formatted(.dateTime.month(.abbreviated).day())) · \(send.sent.formatted()) sent")
                    .font(.caption)
                    .foregroundStyle(Color.compassSecondaryText)
                if hasHighUnsubscribes, let rate = totals.unsubscribeRate {
                    Label("\(EmailFormat.compactPercent(rate)) unsubs", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(Color.compassOrange)
                        .background(Color.compassOrangeTint, in: .capsule)
                        .accessibilityLabel("High unsubscribes: \(EmailFormat.compactPercent(rate))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                RateFigure(value: totals.openRate, label: "opens")
                RateFigure(value: totals.clickRate, label: "clicks")
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct RateFigure: View {
    let value: Decimal?
    let label: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value.map(EmailFormat.compactPercent) ?? "–")
                .font(.system(.body, design: .rounded, weight: .semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.compassSecondaryText)
        }
        .frame(minWidth: 52, alignment: .trailing)
    }
}

private struct WeekdayChart: View {
    let days: [EmailStats.WeekdayRate]
    let bestWeekday: Int

    var body: some View {
        Chart(days) { day in
            // Days with too few sends aren't drawn: a tall bar from one email would
            // outshine the day named best.
            if let rate = day.clickRate, day.sends >= EmailStats.minimumSendsForBestDay {
                BarMark(
                    x: .value("Day", Self.shortName(day.weekday)),
                    y: .value("Click rate", NSDecimalNumber(decimal: rate).doubleValue),
                    width: .ratio(0.6)
                )
                .cornerRadius(6)
                .foregroundStyle(day.weekday == bestWeekday ? Color.compassTeal : Color.compassTealLight)
                .annotation(position: .top, spacing: 4) {
                    if day.weekday == bestWeekday {
                        Text(EmailFormat.compactPercent(rate))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.compassTeal)
                    }
                }
            }
        }
        // Keep all seven days on the axis, even ones with no sends.
        .chartXScale(domain: days.map { Self.shortName($0.weekday) })
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(Color.compassSecondaryText)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Click rate by day of the week")
        .accessibilityValue(summary)
    }

    /// e.g. "Tuesday is highest, at 5.2%. Saturday is lowest, at 2.1%."
    private var summary: String {
        let withSends = days
            .filter { $0.sends >= EmailStats.minimumSendsForBestDay }
            .compactMap { day in day.clickRate.map { (weekday: day.weekday, rate: $0) } }
        guard let best = withSends.first(where: { $0.weekday == bestWeekday }) else { return "" }
        var text = "\(Self.fullName(best.weekday)) is highest, at \(EmailFormat.compactPercent(best.rate))."
        if let lowest = withSends.min(by: { $0.rate < $1.rate }), lowest.weekday != best.weekday {
            text += " \(Self.fullName(lowest.weekday)) is lowest, at \(EmailFormat.compactPercent(lowest.rate))."
        }
        return text
    }

    private static func shortName(_ weekday: Int) -> String {
        Calendar.current.shortWeekdaySymbols[weekday - 1]
    }

    private static func fullName(_ weekday: Int) -> String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }
}

#Preview {
    EmailView(model: EmailViewModel(credentials: ENCredentials(region: .test, token: "1")))
}
