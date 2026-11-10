//
//  CompassStore.swift
//  Compass
//
//  The one on-device database (SwiftData), shared by the screens and by the
//  background refresh, which runs when no screen exists.
//

import SwiftData

enum CompassStore {
    static let container: ModelContainer = {
        do {
            #if DEBUG
            if DebugUITestDemo.isOn {
                // The UI test gets an empty database of its own, in memory.
                return try ModelContainer(for: FollowedPage.self, SupporterSnapshot.self, SavedNumbers.self,
                                          configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            }
            #endif
            return try ModelContainer(for: FollowedPage.self, SupporterSnapshot.self, SavedNumbers.self)
        } catch {
            // Nothing in the app works without its database.
            fatalError("Compass couldn't open its database: \(error)")
        }
    }()
}
