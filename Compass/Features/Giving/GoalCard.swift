//
//  GoalCard.swift
//  Compass
//
//  Giving: a thermometer toward the goal the user set for a donation page, and
//  whether recent giving is fast enough to reach it by the deadline.
//

import SwiftUI

struct GoalCard: View {
    let pace: GoalPace
    /// Nil when the goal has no deadline.
    let deadline: Date?
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Goal")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Edit", action: onEdit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.compassTeal)
                    .accessibilityLabel("Edit goal")
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(pace.percent)%")
                        .font(.system(.title, design: .rounded, weight: .semibold))
                    Text("\(money(pace.raised)) of \(money(pace.goal))")
                        .font(.subheadline)
                        .foregroundStyle(Color.compassSecondaryText)
                    Spacer()
                }
                Thermometer(fraction: pace.fraction)
                    .frame(height: 14)
                if let badge {
                    Text(badge.text)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(badge.isGood ? Color.compassTeal : Color.compassOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(badge.isGood ? Color.compassTealTint : Color.compassOrangeTint, in: .capsule)
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.compassSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Goal progress")
            .accessibilityValue(spokenSummary)
        }
        .compassCard()
    }

    // MARK: Wording

    /// Good or bad is shown with the glyph as well as the color.
    private var badge: (text: String, isGood: Bool)? {
        switch pace.outlook {
        case .reached: ("▲ Goal reached", true)
        case .onTrack: ("▲ On track", true)
        case .behind: ("▼ Behind pace", false)
        case .ended: ("▼ Ended short of the goal", false)
        case .noDeadline: nil
        }
    }

    private var detail: String {
        switch pace.outlook {
        case .reached:
            let over = pace.raised - pace.goal
            return over > 0 ? "\(money(over)) over the goal." : "Right on the goal."
        case .noDeadline:
            return "\(money(pace.remaining)) to go."
        case .ended:
            return "\(money(pace.remaining)) short when it ended on \(deadlineText)."
        case .onTrack(let needed, let recent):
            return "\(money(pace.remaining)) to go, \(daysLeftText). That takes about \(money(needed)) a day; the last \(GoalPace.recentDays) days brought in about \(money(recent)) a day."
        case .behind(let needed, let recent):
            return "\(money(pace.remaining)) to go, \(daysLeftText). That takes about \(money(needed)) a day, but the last \(GoalPace.recentDays) days brought in about \(money(recent)) a day."
        }
    }

    /// "10 days left (through Nov 19)"
    private var daysLeftText: String {
        switch pace.daysLeft {
        case 1: "and today is the last day"
        case let days?: "with \(days) days left (through \(deadlineText))"
        case nil: ""
        }
    }

    private var deadlineText: String {
        deadline?.formatted(.dateTime.month(.abbreviated).day()) ?? ""
    }

    private var spokenSummary: String {
        let status = badge.map { String($0.text.dropFirst(2)) + ". " } ?? ""
        return "\(pace.percent) percent. \(money(pace.raised)) of \(money(pace.goal)). \(status)\(detail)"
    }

    private func money(_ amount: Decimal) -> String {
        Fact.format(amount, unit: .money(currencyCode: AccountSettings.reportingCurrency))
    }
}

/// A bar that fills from the left as the goal gets closer.
private struct Thermometer: View {
    /// 0…1
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.compassTealTint)
                Capsule().fill(Color.compassTeal)
                    // Anything raised at all shows as at least a dot.
                    .frame(width: fraction > 0 ? max(geometry.size.height, geometry.size.width * fraction) : 0)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack {
        GoalCard(pace: GoalPace(goal: 10_000, raised: 4_250, recentRaised: 2_100,
                                deadline: .now.addingTimeInterval(10 * 86_400), now: .now),
                 deadline: .now.addingTimeInterval(10 * 86_400)) {}
        GoalCard(pace: GoalPace(goal: 10_000, raised: 12_000, recentRaised: 0, deadline: nil, now: .now),
                 deadline: nil) {}
    }
    .padding()
    .background(Color.compassBackground)
}
