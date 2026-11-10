//
//  WidgetSnapshot.swift
//  CompassWidget
//
//  The numbers the app leaves for the widget in the shared App Group. This is the
//  widget's copy of the shape in Compass/Store/WidgetSnapshot.swift: change both together.
//

import Foundation

struct WidgetSnapshot: Codable, Hashable, Sendable {
    struct Item: Codable, Hashable, Sendable {
        let title: String
        let value: String
        let change: String?
        let isGood: Bool?
    }

    static let appGroup = "group.com.fursa.Compass"
    static let key = "widget.pulse"

    let updatedAt: Date
    let periodTitle: String
    let items: [Item]

    /// What the app saved last. Nil before the first refresh, or after Disconnect.
    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Made-up numbers for the widget gallery.
    static let sample = WidgetSnapshot(
        updatedAt: .now,
        periodTitle: "Last 7 days",
        items: [
            Item(title: "Supporters", value: "48,312", change: "▲ 214", isGood: true),
            Item(title: "New joins", value: "386", change: "▲ 13%", isGood: true),
            Item(title: "Raised", value: "$23,480", change: "▲ 8%", isGood: true),
            Item(title: "Email opens", value: "38.2%", change: "▼ 1.4 pts", isGood: false),
        ]
    )
}
