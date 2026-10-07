//
//  ENDateFormat.swift
//  Compass
//
//  The EN API uses two date formats. Named after the format, not the service:
//  - iso:      YYYY-MM-DD (EventDetails, FundraisingSummaryByPage)
//  - ddMMyyyy: DD/MM/YYYY (AccountReports, EaBroadcastInfo)
//  Parsed iso dates are UTC midnight; display them with a UTC time zone so the day doesn't shift.
//  Parsed ddMMyyyy dates are the start of that day in the user's calendar, the same calendar
//  ddMMyyyyString writes with, so they line up with DayRange and display without a time zone.
//

import Foundation

nonisolated enum ENDateFormat {
    private static let isoStyle = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()

    /// Parses "2026-10-04". Tolerates a trailing time ("2026-10-04 00:00:00").
    static func iso(_ string: String) -> Date? {
        let datePart = String(string.trimmingCharacters(in: .whitespaces).prefix(10))
        return try? Date(datePart, strategy: isoStyle)
    }

    static func isoString(from date: Date) -> String {
        date.formatted(isoStyle)
    }

    /// "2026-10-04" for the calendar day `date` falls on in `calendar`. Use this for
    /// DayRange days, which start at midnight in the user's own time zone.
    static func isoString(from date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// "24/09/2026" for the calendar day `date` falls on in `calendar` (the user's own by default).
    static func ddMMyyyyString(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        return String(format: "%02d/%02d/%04d", parts.day ?? 0, parts.month ?? 0, parts.year ?? 0)
    }

    /// Parses "06/10/2026" (6 October) as the start of that day in `calendar`.
    /// Tolerates a trailing time ("06/10/2026 00:00:00").
    static func ddMMyyyy(_ string: String, calendar: Calendar = .current) -> Date? {
        let parts = string.trimmingCharacters(in: .whitespaces).prefix(10).split(separator: "/")
        guard parts.count == 3, parts[2].count == 4,
              let day = Int(parts[0]), let month = Int(parts[1]), let year = Int(parts[2])
        else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        // Rejects days that don't exist, like 31/02/2026.
        guard components.isValidDate(in: calendar) else { return nil }
        return calendar.date(from: components)
    }
}
