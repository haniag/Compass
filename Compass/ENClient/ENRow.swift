//
//  ENRow.swift
//  Compass
//
//  Generic decoding for the EN data service's flat-file JSON:
//  { "rows": [ { "columns": [ { "name": "...", "value": "..." } ] } ] }
//  or, on failure (still HTTP 200): { "error": "..." }
//

import Foundation

nonisolated struct ENResponse: Decodable, Sendable {
    let rows: [ENRow]?
    let error: String?

    /// Decodes a data service reply into rows, turning EN's in-body errors into ENError.
    static func rows(from data: Data) throws(ENError) -> [ENRow] {
        let decoded: ENResponse
        do {
            decoded = try JSONDecoder().decode(ENResponse.self, from: data)
        } catch {
            throw .unexpectedResponse
        }

        // EN reports failures as HTTP 200 + {"error": "..."}. Never log that message:
        // it contains the token.
        if let message = decoded.error {
            throw message.localizedCaseInsensitiveContains("token") ? .invalidToken : .serviceError
        }
        guard let rows = decoded.rows else { throw .unexpectedResponse }
        return rows
    }
}

/// One row as a name → value dictionary. Every value is a string.
/// Column names are matched ignoring case, underscores and spaces, so
/// `row["supporterCount"]` also finds `SUPPORTER_COUNT`, and `row["jobId"]` finds `JOB ID`.
nonisolated struct ENRow: Decodable, Sendable {
    private let values: [String: String]

    init(_ values: [String: String]) {
        self.values = Dictionary(values.map { (Self.normalize($0.key), $0.value) }, uniquingKeysWith: { first, _ in first })
    }

    subscript(name: String) -> String? {
        values[Self.normalize(name)]
    }

    func string(_ name: String) -> String? {
        guard let raw = self[name]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return raw
    }

    /// Parses "1234", "1,234" or "1234.0".
    func int(_ name: String) -> Int? {
        guard let raw = string(name)?.replacingOccurrences(of: ",", with: "") else { return nil }
        if let value = Int(raw) { return value }
        if let value = Double(raw), value.isFinite, value == value.rounded() { return Int(value) }
        return nil
    }

    /// Parses "2384490.0", "357.44" or "1,234.5" exactly (no Double rounding), for money and rates.
    func decimal(_ name: String) -> Decimal? {
        guard let raw = string(name)?.replacingOccurrences(of: ",", with: "") else { return nil }
        return Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased().filter { $0 != "_" && $0 != " " }
    }

    // MARK: Decodable

    private enum CodingKeys: String, CodingKey { case columns }

    private struct Column: Decodable {
        let name: String
        let value: String?

        private enum CodingKeys: String, CodingKey { case name, value }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            // Documented as a string, but tolerate numbers or null.
            if let string = try? container.decodeIfPresent(String.self, forKey: .value) {
                value = string
            } else if let number = try? container.decodeIfPresent(Double.self, forKey: .value) {
                value = String(number)
            } else {
                value = nil
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let columns = try container.decodeIfPresent([Column].self, forKey: .columns) ?? []
        var values: [String: String] = [:]
        for column in columns {
            values[column.name] = column.value ?? ""
        }
        self.init(values)
    }
}
