//
//  ContentView.swift
//  Compass
//
//  Root view: onboarding until a token is saved and pages are chosen, then the app.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var credentials: ENCredentials? = CredentialStore.load()
    @AppStorage("hasFinishedOnboarding") private var hasFinishedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let credentials, hasFinishedOnboarding {
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
            if let credentials {
                await DebugDefaultPages.followIfNeeded(credentials: credentials, in: modelContext)
            }
        }
        #endif
    }

    private func disconnect() {
        CredentialStore.delete()
        try? modelContext.delete(model: FollowedPage.self)
        try? modelContext.delete(model: SupporterSnapshot.self)
        try? modelContext.save()
        #if DEBUG
        DebugDefaultPages.reset()
        #endif
        hasFinishedOnboarding = false
        credentials = nil
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FollowedPage.self, SupporterSnapshot.self], inMemory: true)
}
