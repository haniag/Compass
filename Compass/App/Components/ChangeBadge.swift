//
//  ChangeBadge.swift
//  Compass
//
//  "▲ 13%" pill. Good vs. needs-attention uses color AND an arrow, never color alone.
//

import SwiftUI

struct ChangeBadge: View {
    let change: FactChange
    /// Appended to the text, e.g. " this week".
    var suffix = ""

    var body: some View {
        Text(change.badgeText + (change.direction == .flat ? "" : suffix))
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(foreground)
            .background(background, in: .capsule)
            .accessibilityLabel(change.spokenSummary + (change.direction == .flat ? "" : suffix))
    }

    private var foreground: Color {
        switch change.isGood {
        case true?: .compassTeal
        case false?: .compassOrange
        case nil: .compassSecondaryText
        }
    }

    private var background: Color {
        switch change.isGood {
        case true?: .compassTealTint
        case false?: .compassOrangeTint
        case nil: .compassBackground
        }
    }
}
