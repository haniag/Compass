//
//  Alerts.swift
//  Compass
//
//  Notifications Compass creates on this iPhone after a background refresh: nothing
//  is sent by a server. Off until the user turns them on in More. They show on the
//  Lock Screen, so they carry totals only, never a supporter's name or city.
//

import Foundation
import os
import SwiftData
import UserNotifications

enum Alerts {
    nonisolated struct Alert: Hashable, Sendable {
        /// The same finding always has the same ID, so it's only announced once.
        let id: String
        let title: String
        let body: String
    }

    /// The More tab's switch.
    static let enabledKey = "alerts.enabled"
    private static let sentKey = "alerts.sent"
    /// Goal pages checked per background refresh, to stay within the few seconds iOS allows.
    private static let maxGoalPages = 5
    private static let log = Logger(subsystem: "com.fursa.Compass", category: "Alerts")

    // MARK: What's worth an alert (pure, tested)

    /// List fatigue: the newest sends all lost supporters faster than usual. Tied to the
    /// newest send, so it's announced again only after another email goes out.
    nonisolated static func listFatigue(_ fatigue: EmailStats.Fatigue?, newestSendId: Int?) -> Alert? {
        guard let fatigue, let newestSendId else { return nil }
        return Alert(
            id: "fatigue.\(newestSendId)",
            title: "Unsubscribes are climbing",
            body: "Your last \(fatigue.sends) emails lost supporters at about \(fatigue.timesUsual) times your usual rate. Consider a short break before the next send."
        )
    }

    /// A donation page passed the goal set for it.
    nonisolated static func goalReached(pageId: Int, pageName: String, goal: Decimal, raised: Decimal,
                                        currency: String) -> Alert? {
        guard goal > 0, raised >= goal else { return nil }
        let amount = Fact.format(raised, unit: .money(currencyCode: currency))
        return Alert(
            id: "goal.\(pageId).\(goal)",
            title: "Goal reached",
            body: "\(pageName) has raised \(amount), past its goal of \(Fact.format(goal, unit: .money(currencyCode: currency)))."
        )
    }

    /// Leaves out alerts already announced.
    nonisolated static func notYetSent(_ alerts: [Alert], sent: [String]) -> [Alert] {
        alerts.filter { !sent.contains($0.id) }
    }

    // MARK: Permission

    /// Asks iOS for permission (the system prompt shows the first time only).
    /// False when the user said no, now or earlier in Settings.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    // MARK: After a background refresh

    /// Checks the fresh numbers and announces anything new.
    static func check(email: EmailViewModel, client: ENClient, in context: ModelContext) async {
        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        var alerts = [listFatigue(email.fatigue, newestSendId: email.recentSends.first?.id)].compactMap { $0 }
        alerts += await goalAlerts(client: client, in: context)

        let sent = UserDefaults.standard.stringArray(forKey: sentKey) ?? []
        let due = notYetSent(alerts, sent: sent)
        for alert in due {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            do {
                // No trigger: deliver now.
                try await UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: alert.id, content: content, trigger: nil))
            } catch {
                log.error("Alert not delivered: \(error.localizedDescription, privacy: .public)")
            }
        }
        // Remember the newest 50; older findings can't come back.
        UserDefaults.standard.set(Array((sent + due.map(\.id)).suffix(50)), forKey: sentKey)
    }

    private static func goalAlerts(client: ENClient, in context: ModelContext) async -> [Alert] {
        let followed = (try? context.fetch(FetchDescriptor<FollowedPage>())) ?? []
        let currency = AccountSettings.reportingCurrency
        let today = Calendar.current.startOfDay(for: .now)
        var alerts: [Alert] = []
        for page in followed.prefix(maxGoalPages * 4) {
            guard alerts.count < maxGoalPages, let pageId = page.pageId, let goal = page.goalAmount else { continue }
            // An error just means no alert this time.
            guard let giving = try? await client.pageGiving(pageId: pageId, from: GivingViewModel.campaignStart, through: today)
            else { continue }
            let raised = GivingStats.Summary(giving, currency: currency).raised
            if let alert = goalReached(pageId: pageId, pageName: page.name, goal: goal, raised: raised, currency: currency) {
                alerts.append(alert)
            }
        }
        return alerts
    }

    /// Disconnecting forgets what was announced, and turns alerts off.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: sentKey)
        UserDefaults.standard.removeObject(forKey: enabledKey)
    }
}
