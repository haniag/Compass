//
//  ConnectViewModel.swift
//  Compass
//
//  Onboarding step 1: pick a data center, enter the token, test it, save it.
//

import Foundation
import Observation

@Observable
final class ConnectViewModel {
    enum Status: Equatable {
        case idle
        case connecting
        case failed(message: String)
    }

    #if DEBUG
    var region: ENRegion = .test
    #else
    var region: ENRegion = .us
    #endif
    var token = ""
    private(set) var status: Status = .idle

    /// `existing` pre-fills the form when coming back from step 2.
    init(existing: ENCredentials? = nil) {
        if let existing {
            region = existing.region
            token = existing.token
        } else {
            #if DEBUG
            // Start filled in with the test account; clear the field and type 1 for demo data.
            region = DebugTestAccount.region
            token = DebugTestAccount.token
            #endif
        }
    }

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasToken: Bool { !trimmedToken.isEmpty }

    var canConnect: Bool {
        hasToken && status != .connecting
    }

    /// Makes one test call. On success saves to the Keychain and returns the credentials.
    func connect() async -> ENCredentials? {
        guard canConnect else { return nil }
        status = .connecting

        let credentials = ENCredentials(region: region, token: trimmedToken)
        do {
            _ = try await ENClient(credentials: credentials).supporterCount()
        } catch {
            status = .failed(message: error.userMessage)
            return nil
        }

        guard CredentialStore.save(credentials) else {
            status = .failed(message: "Your token worked, but Compass couldn’t save it on this iPhone. Try again.")
            return nil
        }
        status = .idle
        return credentials
    }

    /// Editing the token or region clears an old error.
    func inputChanged() {
        if case .failed = status { status = .idle }
    }
}
