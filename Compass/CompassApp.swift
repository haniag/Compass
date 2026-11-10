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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(CompassStore.container)
        .onChange(of: scenePhase) {
            // Leaving the app: ask iOS to wake Compass tomorrow morning to refresh.
            if scenePhase == .background {
                BackgroundRefresh.schedule()
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.taskIdentifier)) {
            await BackgroundRefresh.run()
        }
    }
}
