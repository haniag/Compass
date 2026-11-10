//
//  DebugUITestDemo.swift
//  Compass
//
//  DEBUG builds only: launching with the argument "-uiTestDemo" opens the app already
//  connected in demo mode (fake data, no network), with two demo donation pages and a
//  goal. The UI smoke test uses it. Nothing is written to the Keychain or to the real
//  database, so it never disturbs the account connected in the simulator.
//

#if DEBUG
import Foundation
import SwiftData

enum DebugUITestDemo {
    static let launchArgument = "-uiTestDemo"

    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains(launchArgument) }

    static let credentials = ENCredentials(region: .test, token: ENDemoData.token)

    /// Fall Appeal (with a goal and a deadline) and Monthly giving.
    static func seedPages(in context: ModelContext) {
        for pageId in [71101, 71102] {
            guard let details = ENDemoData.pageDetails(pageId: pageId) else { continue }
            let page = FollowedPage.follow(details, in: context)
            if pageId == 71101, page.goalAmount == nil {
                page.goalAmount = 250_000
                page.goalDeadline = Calendar.current.date(byAdding: .day, value: 30, to: Calendar.current.startOfDay(for: .now))
            }
        }
        try? context.save()
    }
}
#endif
