//
//  DebugDefaultPages.swift
//  Compass
//
//  DEBUG builds only: the owner's test-account donation pages, followed by default so
//  Giving has pages without pasting links in the simulator. Only for the test account
//  in DebugTestAccount.swift, and only once per install: a page removed stays removed.
//

#if DEBUG
import Foundation
import SwiftData

enum DebugDefaultPages {
    /// Watershed Donation, IATS Donation Page, Alexey P2P donation page (origin).
    static let pageIds = [16105, 12071, 16315]

    private static let followedKey = "debugDefaultPagesFollowed"
    private static var isFollowing = false

    /// Follows the pages if this is the test account and they haven't been followed before.
    static func followIfNeeded(credentials: ENCredentials, in context: ModelContext) async {
        guard credentials.region == DebugTestAccount.region,
              credentials.token == DebugTestAccount.token,
              !UserDefaults.standard.bool(forKey: followedKey),
              !isFollowing
        else { return }
        isFollowing = true
        defer { isFollowing = false }

        let client = ENClient(credentials: credentials)
        var allLookedUp = true
        for pageId in pageIds {
            do {
                let details = try await client.pageDetails(pageId: pageId)
                if details.takesGifts {
                    FollowedPage.follow(details, in: context)
                }
            } catch {
                // Offline or the page went away: try again next launch.
                allLookedUp = false
            }
        }
        if allLookedUp {
            UserDefaults.standard.set(true, forKey: followedKey)
        }
    }

    /// After Disconnect, connecting again follows them again.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: followedKey)
    }
}
#endif
