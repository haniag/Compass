//
//  ENCredentials.swift
//  Compass
//
//  The region + public token pair saved in the Keychain.
//

import Foundation

nonisolated struct ENCredentials: Codable, Hashable, Sendable {
    var region: ENRegion
    var token: String

    /// Debug builds only: the token "1" makes ENClient answer with built-in fake data.
    var isDemo: Bool {
        #if DEBUG
        token == ENDemoData.token
        #else
        false
        #endif
    }
}

// Keeps the token out of print(), string interpolation and debugger summaries.
extension ENCredentials: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "ENCredentials(region: \(region.rawValue), token: <redacted>)" }
    var debugDescription: String { description }
}
