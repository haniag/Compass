//
//  ENError.swift
//  Compass
//

import Foundation

nonisolated enum ENError: Error, Equatable, Sendable {
    /// EN rejected the token (wrong token, or wrong data center for it).
    case invalidToken
    /// EN answered with an error for this service (e.g. disabled for the account).
    /// The raw message is deliberately not kept: EN echoes the token and client IP in it.
    case serviceError
    /// No connection, timeout, DNS failure…
    case network
    case httpStatus(Int)
    /// The response wasn't the JSON shape we expect.
    case unexpectedResponse
    /// A page link led nowhere: no such page in this data center, or it isn't live.
    case pageUnavailable

    /// Plain-language text for the UI.
    var userMessage: String {
        switch self {
        case .invalidToken:
            "That token wasn’t accepted. Check that you copied all of it and picked the data center you sign in to."
        case .serviceError:
            "Engaging Networks couldn’t share this data. It may be turned off for your account."
        case .network:
            "Couldn’t reach Engaging Networks. Check your internet connection and try again."
        case .httpStatus, .unexpectedResponse:
            "Engaging Networks sent an answer Compass didn’t understand. Try again in a few minutes."
        case .pageUnavailable:
            "Compass couldn’t find a live page with that link in your account. Check that the page is published."
        }
    }
}
