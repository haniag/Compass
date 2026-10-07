//
//  ConnectView.swift
//  Compass
//
//  Onboarding step 1 of 2 ("Connect your account").
//

import SwiftUI

struct ConnectView: View {
    var onConnected: (ENCredentials) -> Void

    @State private var model: ConnectViewModel
    @FocusState private var tokenFocused: Bool

    private static let tokenHelpURL = URL(string: "https://knowledge.engagingnetworks.net/datareports/public-data-services-using-a-token-public-api")!

    init(existing: ENCredentials? = nil, onConnected: @escaping (ENCredentials) -> Void) {
        self.onConnected = onConnected
        _model = State(initialValue: ConnectViewModel(existing: existing))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                regionPicker
                    .padding(.top, 8)
                tokenField
                if case .failed(let message) = model.status {
                    errorBanner(message)
                }
                privacyNote
                Spacer(minLength: 20)
                connectButton
                Link("Where do I find my token?", destination: Self.tokenHelpURL)
                    .font(.subheadline)
                    .foregroundStyle(Color.compassTeal)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.compassBackground)
        .foregroundStyle(Color.compassText)
        .onChange(of: model.token) { model.inputChanged() }
        .onChange(of: model.region) { model.inputChanged() }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Step 1 of 2")
                .font(.subheadline)
                .foregroundStyle(Color.compassSecondaryText)

            Image(systemName: "location.north.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.compassTeal, in: .rect(cornerRadius: 18))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text("Connect your account")
                    .font(.compassScreenTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("Compass reads your Engaging Networks data to show how your gifts, emails and campaigns are doing.")
                    .foregroundStyle(Color.compassSecondaryText)
            }
        }
    }

    private var regionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data center")
                .font(.subheadline.weight(.semibold))
            Picker("Data center", selection: $model.region) {
                ForEach(ENRegion.allCases) { region in
                    Text(region.displayName).tag(region)
                }
            }
            .pickerStyle(.segmented)
            Text("Match the address you use to sign in to Engaging Networks.")
                .font(.footnote)
                .foregroundStyle(Color.compassSecondaryText)
        }
    }

    private var tokenField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Public token")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                SecureField("Paste your token", text: $model.token)
                    .focused($tokenFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .privacySensitive()
                    .submitLabel(.go)
                    .onSubmit(connect)
                    .accessibilityLabel("Public token")
                // PasteButton reads the clipboard without iOS's "Allow Paste?" prompt.
                PasteButton(payloadType: String.self) { strings in
                    if let pasted = strings.first {
                        model.token = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .tint(Color.compassTeal)
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .frame(minHeight: 52)
            .background(Color.compassCard, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(tokenFocused ? Color.compassTeal : Color.compassDivider, lineWidth: 1)
            }
            Text("A Super Admin can create one in Hello › Account settings › Tokens.")
                .font(.footnote)
                .foregroundStyle(Color.compassSecondaryText)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Color.compassOrange)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.compassOrangeTint, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Problem: \(message)")
    }

    private var privacyNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "lock.shield")
                .foregroundStyle(Color.compassTeal)
                .accessibilityHidden(true)
            Text("Your token stays in this iPhone’s Keychain. Compass talks only to Engaging Networks, and insights are written on the device.")
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.compassTealTint, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var connectButton: some View {
        Button(action: connect) {
            ZStack {
                Text("Connect").opacity(model.status == .connecting ? 0 : 1)
                if model.status == .connecting {
                    ProgressView().tint(.white)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .compassPrimaryButton()
        // Stays teal while connecting so the spinner is visible; connect() ignores repeat taps.
        .disabled(!model.hasToken)
        .accessibilityLabel(model.status == .connecting ? "Connecting" : "Connect")
    }

    // MARK: Actions

    private func connect() {
        tokenFocused = false
        Task {
            if let credentials = await model.connect() {
                onConnected(credentials)
            }
        }
    }
}

#Preview {
    ConnectView { _ in }
}
