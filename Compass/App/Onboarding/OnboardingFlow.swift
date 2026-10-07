//
//  OnboardingFlow.swift
//  Compass
//
//  Connect (step 1) → Choose what to follow (step 2).
//

import SwiftUI

struct OnboardingFlow: View {
    @Binding var credentials: ENCredentials?
    var onFinish: () -> Void

    private enum Step: Hashable {
        case addPages
    }

    @State private var path: [Step]

    init(credentials: Binding<ENCredentials?>, onFinish: @escaping () -> Void) {
        _credentials = credentials
        self.onFinish = onFinish
        // Already connected (e.g. the app was closed during step 2): resume at step 2.
        _path = State(initialValue: credentials.wrappedValue == nil ? [] : [.addPages])
    }

    var body: some View {
        NavigationStack(path: $path) {
            ConnectView(existing: credentials) { connected in
                credentials = connected
                path = [.addPages]
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: Step.self) { _ in
                if let credentials {
                    AddPagesView(credentials: credentials, onContinue: onFinish)
                        // A new token means a fresh list.
                        .id(credentials)
                }
            }
        }
    }
}
