//
//  ENBroadcast.swift
//  Compass
//
//  One row of EaBroadcastInfo: an email send and what supporters did with it.
//

import Foundation

nonisolated struct ENBroadcast: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    /// Start of the send day. EN gives the day only (DD/MM/YYYY), no time.
    let sentOn: Date
    let sent: Int
    let opens: Int
    let clicks: Int
    let unsubscribes: Int

    init(id: Int, name: String, sentOn: Date, sent: Int, opens: Int, clicks: Int, unsubscribes: Int) {
        self.id = id
        self.name = name
        self.sentOn = sentOn
        self.sent = sent
        self.opens = opens
        self.clicks = clicks
        self.unsubscribes = unsubscribes
    }

    init?(row: ENRow, calendar: Calendar = .current) {
        guard let id = row.int("broadcastId"),
              let sentOn = row.string("broadcastDate").flatMap({ ENDateFormat.ddMMyyyy($0, calendar: calendar) })
        else { return nil }
        self.init(
            id: id,
            name: row.string("broadcastName") ?? row.string("exportName") ?? "Email \(id)",
            sentOn: sentOn,
            sent: row.int("sendCount") ?? 0,
            opens: row.int("openCount") ?? 0,
            clicks: row.int("clickCount") ?? 0,
            unsubscribes: row.int("unsubscribeCount") ?? 0
        )
    }
}
