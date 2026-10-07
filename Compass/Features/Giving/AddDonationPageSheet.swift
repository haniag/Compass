//
//  AddDonationPageSheet.swift
//  Compass
//
//  Paste a donation page's link to follow it. Giving needs the page's own ID,
//  and only the link has it (the campaign list doesn't).
//

import Observation
import SwiftData
import SwiftUI

@Observable
final class AddDonationPageModel {
    enum Status: Equatable {
        case idle
        case looking
        case failed(message: String)
    }

    var linkText = "" {
        // An old error doesn't apply to a new link.
        didSet { if case .failed = status { status = .idle } }
    }
    private(set) var status: Status = .idle
    private let client: ENClient

    init(credentials: ENCredentials) {
        client = ENClient(credentials: credentials)
    }

    var canAdd: Bool {
        !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && status != .looking
    }

    /// Looks the page up and follows it. Returns its page ID when that worked.
    func add(in context: ModelContext) async -> Int? {
        guard let pageId = ENPageLink.pageId(from: linkText) else {
            status = .failed(message: "That doesn’t look like a page link. It should have /page/ and a number in it, like …/page/12345/donate/1.")
            return nil
        }
        status = .looking
        do {
            let details = try await client.pageDetails(pageId: pageId)
            guard details.takesGifts else {
                status = .failed(message: "That’s a \(details.typeLabel) page, so it has no gifts to show. Add a donation page instead.")
                return nil
            }
            FollowedPage.follow(details, in: context)
            status = .idle
            return details.pageId
        } catch {
            status = .failed(message: error.userMessage)
            return nil
        }
    }
}

struct AddDonationPageSheet: View {
    private let onAdded: (Int) -> Void

    @State private var model: AddDonationPageModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFieldFocused: Bool

    init(credentials: ENCredentials, onAdded: @escaping (Int) -> Void = { _ in }) {
        _model = State(initialValue: AddDonationPageModel(credentials: credentials))
        self.onAdded = onAdded
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Paste the link to a donation page. Compass uses it to show that page’s gifts, one-time and recurring, over the last 7 and 30 days.")
                        .foregroundStyle(Color.compassSecondaryText)
                    HStack(spacing: 8) {
                        TextField("https://…/page/12345/donate/1", text: $model.linkText)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($isFieldFocused)
                            .onSubmit { Task { await add() } }
                            .accessibilityLabel("Donation page link")
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .background(Color.compassCard, in: .rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14).strokeBorder(Color.compassDivider, lineWidth: 1.5)
                            }
                        PasteButton(payloadType: String.self) { strings in
                            model.linkText = strings.first ?? ""
                        }
                        .labelStyle(.iconOnly)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .tint(Color.compassTeal)
                    }
                    if case .failed(let message) = model.status {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(Color.compassOrange)
                    }
                    Button {
                        Task { await add() }
                    } label: {
                        Group {
                            if model.status == .looking {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Add page")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .compassPrimaryButton()
                    // Not disabled while looking: that would grey out the spinner.
                    // add() ignores taps until the lookup is done.
                    .disabled(model.linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("To find the link, open the page in a browser and copy its address. Typing just the page number works too.")
                        .font(.footnote)
                        .foregroundStyle(Color.compassSecondaryText)
                }
                .padding(20)
            }
            .background(Color.compassBackground)
            .foregroundStyle(Color.compassText)
            .navigationTitle("Add a donation page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { isFieldFocused = true }
        }
        .presentationDetents([.large])
    }

    private func add() async {
        guard model.canAdd, let pageId = await model.add(in: modelContext) else { return }
        onAdded(pageId)
        dismiss()
    }
}

#Preview {
    AddDonationPageSheet(credentials: ENCredentials(region: .test, token: "1"))
        .modelContainer(for: FollowedPage.self, inMemory: true)
}
