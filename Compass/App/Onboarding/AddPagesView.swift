//
//  AddPagesView.swift
//  Compass
//
//  Onboarding step 2 of 2 ("Choose what to follow").
//

import SwiftData
import SwiftUI

struct AddPagesView: View {
    var onContinue: () -> Void

    private let credentials: ENCredentials
    @State private var model: AddPagesViewModel
    @State private var showingPicker = false
    @State private var addingDonationPage = false
    @Query(sort: \FollowedPage.name) private var followed: [FollowedPage]
    @Environment(\.modelContext) private var modelContext

    private static let campaignIDHelpURL = URL(string: "https://knowledge.engagingnetworks.net/datareports/public-data-services-using-a-token-public-api#Publicdataservicesusingatoken(publicAPI)-campaignId")!

    init(credentials: ENCredentials, onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
        self.credentials = credentials
        _model = State(initialValue: AddPagesViewModel(credentials: credentials))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                pagesCard
                donationPagesCard
                eventsCard
                Button {
                    model.save(in: modelContext)
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .compassPrimaryButton()
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.compassBackground)
        .foregroundStyle(Color.compassText)
        .sheet(isPresented: $showingPicker) {
            PagePickerSheet(model: model)
        }
        .sheet(isPresented: $addingDonationPage) {
            AddDonationPageSheet(credentials: credentials)
        }
        .task { await model.load(alreadyFollowed: followed) }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Step 2 of 2")
                .font(.subheadline)
                .foregroundStyle(Color.compassSecondaryText)
            Text("Choose what to follow")
                .font(.compassScreenTitle)
                .accessibilityAddTraits(.isHeader)
            Text("Pick what Compass should track. You can change this any time.")
                .foregroundStyle(Color.compassSecondaryText)
        }
    }

    private var pagesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Donation, action and survey pages")
                .font(.headline)

            switch model.campaigns {
            case .loading:
                dropdownButton(loading: true)
            case .loaded:
                dropdownButton(loading: false)
            case .unavailable:
                manualEntry
            }

            if model.selectedPages.isEmpty {
                Text("No pages selected yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.compassSecondaryText)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(model.selectedPages, id: \.id) { page in
                        chip(name: page.name) { model.toggle(page.id) }
                    }
                }
            }
        }
        .compassCard()
    }

    private func dropdownButton(loading: Bool) -> some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 8) {
                if loading {
                    ProgressView()
                    Text("Loading your pages…")
                        .foregroundStyle(Color.compassSecondaryText)
                } else {
                    Text(model.pickerSummary)
                        .foregroundStyle(Color.compassText)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.compassTeal)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Color.compassBackground, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(Color.compassDivider, lineWidth: 1.5)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(loading)
        .accessibilityHint("Opens a searchable list of pages in your account")
    }

    private func chip(name: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: 6) {
                Text(name)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.compassTeal)
            .padding(.leading, 12)
            .padding(.trailing, 10)
            .frame(minHeight: 36)
            .background(Color.compassTealTint, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(name)")
    }

    /// Donation pages added by link: the only way Giving can show a page (it needs the
    /// page's own ID, and the campaign list above doesn't have it).
    private var donationPagesCard: some View {
        let linked = followed.filter { $0.pageId != nil }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Donation pages for Giving")
                .font(.headline)
            Text("Paste a donation page’s link to see what it raises, day by day, in the Giving tab.")
                .font(.subheadline)
                .foregroundStyle(Color.compassSecondaryText)
            if !linked.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(linked) { page in
                        chip(name: page.name) { model.stopFollowing(page, in: modelContext) }
                    }
                }
            }
            Button {
                addingDonationPage = true
            } label: {
                Label(linked.isEmpty ? "Add a donation page" : "Add another", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.compassTeal)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .compassCard()
    }

    /// Shown when EN won't list the account's campaigns: add them one by one by ID.
    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Compass couldn’t get the list of pages from your account. You can add them by campaign ID instead.")
                .font(.subheadline)
                .foregroundStyle(Color.compassSecondaryText)
            HStack(spacing: 8) {
                TextField("Campaign ID", text: $model.manualIDText)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .background(Color.compassBackground, in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).strokeBorder(Color.compassDivider, lineWidth: 1.5)
                    }
                Button {
                    Task { await model.addManualCampaign() }
                } label: {
                    if model.manualLookup == .looking {
                        ProgressView()
                    } else {
                        Text("Add").fontWeight(.semibold)
                    }
                }
                .frame(minWidth: 60, minHeight: 52)
                .foregroundStyle(Color.compassTeal)
                .disabled(model.manualIDText.isEmpty || model.manualLookup == .looking)
            }
            if case .failed(let message) = model.manualLookup {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(Color.compassOrange)
            }
            Link("How do I find a campaign ID?", destination: Self.campaignIDHelpURL)
                .font(.subheadline)
                .foregroundStyle(Color.compassTeal)
                .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private var eventsCard: some View {
        switch model.events {
        case .loading:
            VStack(alignment: .leading, spacing: 10) {
                eventsHeader
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .compassCard()
        case .loaded(let events) where !events.isEmpty:
            VStack(alignment: .leading, spacing: 0) {
                eventsHeader
                    .padding(.bottom, 4)
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    if index > 0 {
                        Divider().overlay(Color.compassDivider)
                    }
                    eventRow(event)
                }
            }
            .compassCard()
        default:
            // No upcoming events, or the service is off for this account: hide the card.
            EmptyView()
        }
    }

    private var eventsHeader: some View {
        HStack {
            Text("Upcoming events")
                .font(.headline)
            Spacer()
            Text("Found for you")
                .font(.caption)
                .foregroundStyle(Color.compassSecondaryText)
        }
    }

    private func eventRow(_ event: ENEvent) -> some View {
        let selected = model.isSelected(event.campaignId)
        return Button {
            model.toggle(event.campaignId)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.square" : "square")
                    .font(.title2)
                    .foregroundStyle(selected ? Color.compassTeal : Color.compassSecondaryText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .font(.body.weight(.semibold))
                    if !event.summary.isEmpty {
                        Text(event.summary)
                            .font(.footnote)
                            .foregroundStyle(Color.compassSecondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 56)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(selected ? "Double-tap to stop following" : "Double-tap to follow")
    }
}

#Preview {
    NavigationStack {
        AddPagesView(credentials: ENCredentials(region: .test, token: "preview")) {}
    }
    .modelContainer(for: [FollowedPage.self, SupporterSnapshot.self], inMemory: true)
}
