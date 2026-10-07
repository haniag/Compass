//
//  GivingView.swift
//  Compass
//
//  Giving tab: "how is this appeal doing, and who's giving?"
//

import Charts
import SwiftData
import SwiftUI

struct GivingView: View {
    @Bindable var model: GivingViewModel
    let credentials: ENCredentials

    @Query(sort: \FollowedPage.name) private var followed: [FollowedPage]
    @State private var addingPage = false
    @ScaledMetric(relativeTo: .largeTitle) private var heroNumberSize: CGFloat = 40

    /// Followed pages that have a page link; only those can show giving.
    private var pages: [GivingViewModel.Page] {
        followed.compactMap { page in
            page.pageId.map { GivingViewModel.Page(pageId: $0, campaignId: page.campaignId, name: page.name) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if pages.isEmpty {
                    noPagesCard
                } else {
                    windowPicker
                    if let message = model.errorMessage {
                        errorBanner(message)
                    }
                    if let numbers = model.numbers {
                        raisedCard(numbers)
                        if let days = model.dailyTotals {
                            dailyCard(days)
                        }
                        if numbers.current.raised > 0 {
                            splitCard(numbers.current)
                        }
                    } else if model.isLoading {
                        ProgressView("Loading gifts…")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }
                    if let gifts = model.recentGifts, !gifts.isEmpty {
                        donorsCard(gifts)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.compassBackground)
        .foregroundStyle(Color.compassText)
        .refreshable { await model.load(force: true) }
        .onChange(of: pages, initial: true) { model.update(pages: pages) }
        .task(id: model.loadKey) { await model.load() }
        .sheet(isPresented: $addingPage) {
            AddDonationPageSheet(credentials: credentials) { pageId in
                model.selectedPageId = pageId
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let page = model.selectedPage {
                Menu {
                    Picker("Donation page", selection: $model.selectedPageId) {
                        ForEach(pages) { page in
                            Text(page.name).tag(Optional(page.pageId))
                        }
                    }
                    Divider()
                    Button("Add a donation page…", systemImage: "plus") { addingPage = true }
                } label: {
                    HStack(spacing: 4) {
                        Text(page.name)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.compassTeal)
                    .frame(minHeight: 28)
                }
                .accessibilityLabel("Donation page: \(page.name)")
                .accessibilityHint("Choose another page, or add one")
            } else {
                Text("Donation pages")
                    .font(.subheadline)
                    .foregroundStyle(Color.compassSecondaryText)
            }
            Text("Giving")
                .font(.compassScreenTitle)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, 8)
    }

    private var windowPicker: some View {
        Picker("Time span", selection: $model.window) {
            ForEach(GivingViewModel.Window.allCases) { window in
                Text(window.title).tag(window)
            }
        }
        .pickerStyle(.segmented)
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.compassOrangeTint, in: .rect(cornerRadius: 16))
    }

    // MARK: Raised

    private func raisedCard(_ numbers: GivingViewModel.Numbers) -> some View {
        let current = numbers.current
        let change = numbers.previous.flatMap { GivingStats.change(current, from: $0) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.raisedTitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.compassSecondaryText)
                Spacer()
                if let change {
                    ChangeBadge(change: change)
                }
            }
            Text(money(current.raised))
                .font(.system(size: heroNumberSize, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(giftsLine(current))
                .font(.subheadline)
                .foregroundStyle(Color.compassSecondaryText)
            if let previous = numbers.previous, let days = model.window.days {
                Text("The \(days) days before: \(money(previous.raised))")
                    .font(.caption)
                    .foregroundStyle(Color.compassSecondaryText)
            }
            if current.hasOtherCurrencies {
                Label("Gifts in other currencies aren’t included in these amounts.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Color.compassSecondaryText)
            }
        }
        .compassCard()
        .accessibilityElement(children: .combine)
    }

    /// "2,278 gifts · average $81", "No gifts yet".
    private func giftsLine(_ summary: GivingStats.Summary) -> String {
        guard summary.gifts > 0 else {
            return model.window.days.map { "No gifts in the last \($0) days" } ?? "No gifts yet"
        }
        let gifts = summary.gifts == 1 ? "1 gift" : "\(summary.gifts.formatted()) gifts"
        guard let average = summary.averageGift else { return gifts }
        return "\(gifts) · average \(money(average))"
    }

    // MARK: Daily total

    private func dailyCard(_ days: [GivingStats.DailyTotal]) -> some View {
        let today = days.last
        let best = GivingStats.bestDay(days)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily total")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("Last \(GivingViewModel.chartDays) days")
                    .font(.footnote)
                    .foregroundStyle(Color.compassSecondaryText)
            }
            if best == nil {
                Text("No gifts in the last \(GivingViewModel.chartDays) days")
                    .font(.subheadline)
                    .foregroundStyle(Color.compassSecondaryText)
            } else {
                Chart(days, id: \.day) { day in
                    BarMark(x: .value("Day", day.day, unit: .day),
                            y: .value("Raised", NSDecimalNumber(decimal: day.raised).doubleValue))
                        .foregroundStyle(day.day == today?.day ? Color.compassTeal : Color.compassTealLight)
                        .cornerRadius(4)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 96)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Daily totals for the last \(GivingViewModel.chartDays) days")
                .accessibilityValue(dailySummary(days, best: best))
                HStack {
                    if let first = days.first {
                        Text(first.day.formatted(.dateTime.month(.abbreviated).day()))
                    }
                    Spacer()
                    if let today {
                        Text("Today · \(money(today.raised))")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.compassSecondaryText)
                .accessibilityHidden(true)
            }
        }
        .compassCard()
    }

    /// "Between $1,200 and $3,900 a day. Best day was Sep 19. Today so far: $2,240."
    private func dailySummary(_ days: [GivingStats.DailyTotal], best: GivingStats.DailyTotal?) -> String {
        let amounts = days.map(\.raised)
        var parts: [String] = []
        if let low = amounts.min(), let high = amounts.max() {
            parts.append("Between \(money(low)) and \(money(high)) a day.")
        }
        if let best {
            parts.append("Best day was \(best.day.formatted(.dateTime.month(.wide).day())).")
        }
        if let today = days.last {
            parts.append("Today so far: \(money(today.raised)).")
        }
        return parts.joined(separator: " ")
    }

    // MARK: One-time and recurring

    private func splitCard(_ summary: GivingStats.Summary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One-time and recurring")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            SplitBar(share: summary.singleShare ?? 1)
                .frame(height: 12)
                .accessibilityHidden(true)
            HStack(alignment: .top) {
                splitFigure("One-time", amount: summary.single, gifts: summary.singleGifts,
                            color: .compassTeal, alignment: .leading)
                Spacer()
                splitFigure("Recurring", amount: summary.recurring, gifts: summary.recurringGifts,
                            color: .compassTealLight, alignment: .trailing)
            }
        }
        .compassCard()
    }

    private func splitFigure(_ title: String, amount: Decimal, gifts: Int, color: Color,
                             alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(Color.compassSecondaryText)
            }
            Text(money(amount))
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(gifts == 1 ? "1 gift" : "\(gifts.formatted()) gifts")
                .font(.caption)
                .foregroundStyle(Color.compassSecondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Recent donors

    /// How many donors to list; the rest are counted.
    private static let donorsShown = 5

    private func donorsCard(_ gifts: [ENRecentGift]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent donors")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("Last 7 days")
                    .font(.footnote)
                    .foregroundStyle(Color.compassSecondaryText)
            }
            .padding(.bottom, 8)
            ForEach(Array(gifts.prefix(Self.donorsShown).enumerated()), id: \.offset) { _, gift in
                Divider()
                    .overlay(Color.compassDivider)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gift.shortName)
                            .font(.subheadline.weight(.semibold))
                        if let city = gift.city {
                            Text(city)
                                .font(.caption)
                                .foregroundStyle(Color.compassSecondaryText)
                        }
                    }
                    Spacer()
                    Text(gift.amount.formatted(.currency(code: gift.currency).precision(.fractionLength(0...2))))
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                .frame(minHeight: 48)
                .accessibilityElement(children: .combine)
            }
            if gifts.count > Self.donorsShown {
                Divider()
                    .overlay(Color.compassDivider)
                Text("and \(gifts.count - Self.donorsShown) more")
                    .font(.footnote)
                    .foregroundStyle(Color.compassSecondaryText)
                    .frame(minHeight: 40)
            }
        }
        .padding(.bottom, -8)
        .compassCard()
    }

    // MARK: No pages yet

    private var noPagesCard: some View {
        VStack(spacing: 14) {
            ContentUnavailableView(
                "Add a donation page",
                systemImage: "heart",
                description: Text("Paste the link to a donation page to see what it raised in the last 7 and 30 days, one-time and recurring gifts, and recent donors.")
            )
            Button {
                addingPage = true
            } label: {
                Text("Add a donation page")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .compassPrimaryButton()
        }
        .compassCard()
    }

    private func money(_ amount: Decimal) -> String {
        Fact.format(amount, unit: .money(currencyCode: AccountSettings.reportingCurrency))
    }
}

/// One-time share (teal) next to recurring (lighter teal), with a small gap.
private struct SplitBar: View {
    /// 0…1
    let share: Double

    var body: some View {
        GeometryReader { geometry in
            let gap: CGFloat = share > 0 && share < 1 ? 3 : 0
            let first = max(0, (geometry.size.width - gap) * share)
            HStack(spacing: gap) {
                if share > 0 {
                    UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6,
                                           bottomTrailingRadius: share >= 1 ? 6 : 0, topTrailingRadius: share >= 1 ? 6 : 0)
                        .fill(Color.compassTeal)
                        .frame(width: first)
                }
                if share < 1 {
                    UnevenRoundedRectangle(topLeadingRadius: share <= 0 ? 6 : 0, bottomLeadingRadius: share <= 0 ? 6 : 0,
                                           bottomTrailingRadius: 6, topTrailingRadius: 6)
                        .fill(Color.compassTealLight)
                }
            }
        }
    }
}

#Preview {
    GivingView(model: GivingViewModel(credentials: ENCredentials(region: .test, token: "1")),
               credentials: ENCredentials(region: .test, token: "1"))
        .modelContainer(for: FollowedPage.self, inMemory: true)
}
