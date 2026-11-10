//
//  ContentView.swift
//  Compass
//
//  Root view: onboarding until a token is saved and pages are chosen, then the app.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var credentials: ENCredentials? = ContentView.startingCredentials
    @AppStorage("hasFinishedOnboarding") private var hasFinishedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let credentials, hasFinishedOnboarding || Self.isUITestDemo {
                MainTabView(credentials: credentials, onDisconnect: disconnect)
            } else {
                OnboardingFlow(credentials: $credentials) {
                    hasFinishedOnboarding = true
                }
            }
        }
        .tint(Color.compassTeal)
        // The design only defines light colors so far.
        .preferredColorScheme(.light)
        #if DEBUG
        .task(id: credentials) {
            if Self.isUITestDemo {
                DebugUITestDemo.seedPages(in: modelContext)
            } else if let credentials {
                await DebugDefaultPages.followIfNeeded(credentials: credentials, in: modelContext)
            }
        }
        #endif
    }

    /// DEBUG builds launched with "-uiTestDemo" (the UI smoke test). Always false otherwise.
    private static var isUITestDemo: Bool {
        #if DEBUG
        DebugUITestDemo.isOn
        #else
        false
        #endif
    }

    private static var startingCredentials: ENCredentials? {
        #if DEBUG
        if DebugUITestDemo.isOn { return DebugUITestDemo.credentials }
        #endif
        return CredentialStore.load()
    }

    private func disconnect() {
        // The UI test's demo never touched the Keychain or saved settings; leave them alone.
        guard !Self.isUITestDemo else {
            credentials = nil
            return
        }
        CredentialStore.delete()
        try? modelContext.delete(model: FollowedPage.self)
        try? modelContext.delete(model: SupporterSnapshot.self)
        try? modelContext.delete(model: SavedNumbers.self)
        try? modelContext.save()
        #if DEBUG
        DebugDefaultPages.reset()
        #endif
        Alerts.reset()
        hasFinishedOnboarding = false
        credentials = nil
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FollowedPage.self, SupporterSnapshot.self, SavedNumbers.self], inMemory: true)
}
