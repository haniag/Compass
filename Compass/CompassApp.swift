//
//  CompassApp.swift
//  Compass
//
//  Created by hani on 9/23/26.
//

import SwiftData
import SwiftUI

@main
struct CompassApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [FollowedPage.self, SupporterSnapshot.self])
    }
}
