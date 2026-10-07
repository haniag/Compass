//
//  PagePickerSheet.swift
//  Compass
//
//  Searchable multi-select list of the account's pages (from EaCampaignInfo).
//

import SwiftUI

struct PagePickerSheet: View {
    @Bindable var model: AddPagesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.filteredPageOptions) { campaign in
                        row(campaign)
                    }
                } footer: {
                    Text("From your Engaging Networks account")
                }
            }
            .overlay {
                if model.filteredPageOptions.isEmpty {
                    if model.searchText.isEmpty {
                        ContentUnavailableView("No pages found", systemImage: "doc.text.magnifyingglass",
                                               description: Text("Your account doesn’t have any pages Compass can follow yet."))
                    } else {
                        ContentUnavailableView.search(text: model.searchText)
                    }
                }
            }
            .searchable(text: $model.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search pages")
            .navigationTitle("Choose pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Color.compassTeal)
        .presentationDetents([.medium, .large])
        .onDisappear { model.searchText = "" }
    }

    private func row(_ campaign: ENCampaign) -> some View {
        let selected = model.isSelected(campaign.id)
        return Button {
            model.toggle(campaign.id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(campaign.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.compassText)
                    Text(campaign.statusLabel)
                        .font(.footnote)
                        .foregroundStyle(Color.compassSecondaryText)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.compassTeal)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
