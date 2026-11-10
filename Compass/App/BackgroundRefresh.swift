//
//  BackgroundRefresh.swift
//  Compass
//
//  Once a day, iOS wakes Compass for a few seconds to fetch the numbers, so the
//  supporter count is saved every day (the trend line needs that) and the app opens
//  with fresh numbers. iOS decides the exact time; it's never earlier than asked.
//

import BackgroundTasks
import Foundation
import os
import SwiftData

enum BackgroundRefresh {
    /// Also listed in Info.plist under "Permitted background task scheduler identifiers".
    static let taskIdentifier = "com.fursa.Compass.refresh"
    /// Ask to be woken from this hour (the user's time), once yesterday's numbers are complete.
    private static let earliestHour = 6
    private static let log = Logger(subsystem: "com.fursa.Compass", category: "Refresh")

    /// Asks iOS for the next wake-up. Safe to call often: a new request replaces the old one.
    static func schedule(now: Date = .now) {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nextWakeUp(after: now)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Expected on the simulator, and when Background App Refresh is off in Settings.
            log.info("Background refresh not scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The next time the clock shows `earliestHour`:00 after `now`.
    nonisolated static func nextWakeUp(after now: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: now, matching: DateComponents(hour: earliestHour, minute: 0, second: 0),
                          matchingPolicy: .nextTime) ?? now.addingTimeInterval(24 * 3_600)
    }

    /// What the wake-up does: the same refresh the Pulse and Email screens do, which
    /// saves the supporter count and the numbers those screens open with.
    static func run() async {
        // Book the next one first, in case iOS stops this one early.
        schedule()
        guard UserDefaults.standard.bool(forKey: "hasFinishedOnboarding"),
              let credentials = CredentialStore.load()
        else { return }

        let context = CompassStore.container.mainContext
        let pulse = PulseViewModel(credentials: credentials)
        let email = EmailViewModel(credentials: credentials)
        async let pulseDone: Void = pulse.refresh(in: context)
        async let emailDone: Void = email.refresh(in: context)
        _ = await (pulseDone, emailDone)
        log.info("Background refresh finished. Pulse updated: \(!pulse.refreshFailed, privacy: .public)")
    }
}
