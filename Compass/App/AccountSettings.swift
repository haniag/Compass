//
//  AccountSettings.swift
//  Compass
//
//  Per-account preferences. Fixed values for now; later chosen by the user.
//

import Foundation

nonisolated enum AccountSettings {
    /// The currency totals are reported in. Each account will pick its own;
    /// until that setting exists, every account uses USD.
    static let reportingCurrency = "USD"
}
