//
//  Theme.swift
//  Compass
//
//  Colors and fonts from the design comps (see CLAUDE.md › Design).
//

import SwiftUI

extension Color {
    /// Accent: buttons, links, active tab, "good" changes.
    static let compassTeal = Color(hex: 0x0E5E6F)
    static let compassTealTint = Color(hex: 0xE4EFED)
    static let compassTealLight = Color(hex: 0x5E949B)

    /// "Needs attention".
    static let compassOrange = Color(hex: 0x9A4309)
    static let compassOrangeTint = Color(hex: 0xFBEDE3)
    static let compassOrangeMark = Color(hex: 0xB4530F)

    static let compassText = Color(hex: 0x16181D)
    static let compassSecondaryText = Color(hex: 0x5F6168)
    static let compassBackground = Color(hex: 0xF5F4F0)
    static let compassCard = Color.white
    static let compassDivider = Color(hex: 0xE7E5DF)
    /// Chip behind "Good news" and "Steady" labels.
    static let compassNeutralTint = Color(hex: 0xECEAE4)

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Font {
    /// Screen titles: New York, bold, scales with Dynamic Type.
    static let compassScreenTitle = Font.system(.largeTitle, design: .serif, weight: .bold)
}

extension View {
    /// The teal capsule used for a screen's main action (Connect, Continue…).
    func compassPrimaryButton() -> some View {
        buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.compassTeal)
            // Screens set a dark text color for everything; the label must stay white.
            .foregroundStyle(.white)
    }

    /// White rounded card on the screen background.
    func compassCard() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.compassCard, in: .rect(cornerRadius: 20))
            .shadow(color: Color.compassText.opacity(0.06), radius: 1, y: 1)
    }
}
