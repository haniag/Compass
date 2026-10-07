//
//  MoreView.swift
//  Compass
//
//  More tab. For now: what you follow (and adding a donation page), and Disconnect.
//

import SwiftData
import SwiftUI

struct MoreView: View {
    let credentials: ENCredentials
    let onDisconnect: () -> Void

    @Query(sort: \FollowedPage.name) private var followed: [FollowedPage]
    @State private var confirmingDisconnect = false
    @State private var addingPage = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if followed.isEmpty {
                        Text("No pages or events yet.")
                            .foregroundStyle(Color.compassSecondaryText)
                    }
                    ForEach(followed) { page in
                        Label(page.name, systemImage: icon(for: page))
                    }
                    Button("Add a donation page", systemImage: "plus") {
                        addingPage = true
                    }
                    .foregroundStyle(Color.compassTeal)
                } header: {
                    Text("Following")
                } footer: {
                    Text("Donation pages added by their link show up in Giving.")
                }
                Section {
                    Button("Disconnect", role: .destructive) {
                        confirmingDisconnect = true
                    }
                } footer: {
                    Text("Removes your token and all saved data from this iPhone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.compassBackground)
            .navigationTitle("More")
            .confirmationDialog("Disconnect from Engaging Networks?", isPresented: $confirmingDisconnect, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive, action: onDisconnect)
            } message: {
                Text("Your token, followed pages and saved history will be removed from this iPhone.")
            }
            .sheet(isPresented: $addingPage) {
                AddDonationPageSheet(credentials: credentials)
            }
        }
    }

    private func icon(for page: FollowedPage) -> String {
        if page.kind == .event { return "calendar" }
        return page.pageId == nil ? "doc.text" : "heart"
    }
}
