//
//  ENRegion.swift
//  Compass
//
//  The Engaging Networks data center an account lives in.
//

import Foundation

nonisolated enum ENRegion: String, CaseIterable, Identifiable, Codable, Sendable {
    case us
    case us2
    case ca
    case test

    var id: String { rawValue }

    /// Label for the Data center picker.
    var displayName: String {
        switch self {
        case .us: "US"
        case .us2: "US2"
        case .ca: "Canada & EU"
        case .test: "Test"
        }
    }

    var host: String { "\(rawValue).engagingnetworks.app" }
}
