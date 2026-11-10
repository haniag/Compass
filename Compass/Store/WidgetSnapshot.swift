//
//  WidgetSnapshot.swift
//  Compass
//
//  What the Home Screen widget shows: Pulse's numbers, already formatted as text.
//  The widget is a separate small program that can't see the app's database, so after
//  each Pulse refresh the app leaves this in the shared App Group for it to read.
//  Totals only: a widget is visible to anyone who sees the phone.
//
//  The widget has its own copy of this shape (CompassWidget/WidgetSnapshot.swift).
//  Change both together.
//

import Foundation
import WidgetKit

nonisolated struct WidgetSnapshot: Codable, Hashable, Sendable {
    struct Item: Codable, Hashable, Sendable {
        /// "Supporters", "Raised"
        let title: String
        /// "48,312", "$23,480"
        let value: String
        /// "▲ 13%". Nil when there's nothing to compare with.
        let change: String?
        /// Whether the change is good news. Nil when flat or unknown.
        let isGood: Bool?
    }

    static let appGroup = "group.com.fursa.Compass"
    static let key = "widget.pulse"

    let updatedAt: Date
    /// "Last 7 days"
    let periodTitle: String
    /// Supporters first, then the period's numbers in Pulse's order.
    let items: [Item]

    init(period: Fact.Period, facts: [Fact], updatedAt: Date) {
        self.updatedAt = updatedAt
        periodTitle = period.title
        items = facts.map { fact in
            let change = fact.change
            return Item(title: fact.displayName, value: fact.formattedValue,
                        change: change?.badgeText, isGood: change?.isGood)
        }
    }

    /// Hands the widget new numbers and asks iOS to redraw it. Nil clears it (Disconnect).
    static func publish(_ snapshot: WidgetSnapshot?) {
        #if DEBUG
        // The UI test's fake numbers must not end up on the Home Screen.
        if DebugUITestDemo.isOn { return }
        #endif
        guard let shared = UserDefaults(suiteName: appGroup) else { return }
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) {
            shared.set(data, forKey: key)
        } else {
            shared.removeObject(forKey: key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
