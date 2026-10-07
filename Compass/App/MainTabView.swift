//
//  MainTabView.swift
//  Compass
//
//  The app after onboarding: five tabs, as in the design comps.
//

import SwiftUI
import UIKit

struct MainTabView: View {
    let credentials: ENCredentials
    let onDisconnect: () -> Void

    private enum AppTab: Hashable {
        case pulse, insights, giving, email, more
    }

    @State private var selection: AppTab = .pulse
    /// Loaded once and shared: Insights is written from the same numbers Pulse shows.
    @State private var pulse: PulseViewModel
    @State private var giving: GivingViewModel
    @State private var email: EmailViewModel

    init(credentials: ENCredentials, onDisconnect: @escaping () -> Void) {
        self.credentials = credentials
        self.onDisconnect = onDisconnect
        _pulse = State(initialValue: PulseViewModel(credentials: credentials))
        _giving = State(initialValue: GivingViewModel(credentials: credentials))
        _email = State(initialValue: EmailViewModel(credentials: credentials))
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: .pulse) {
                PulseView(model: pulse) { selection = .insights }
            } label: {
                tabLabel("Pulse", systemImage: "waveform.path.ecg", for: .pulse)
            }
            Tab(value: .insights) {
                InsightsView(pulse: pulse)
            } label: {
                tabLabel("Insights", systemImage: "sparkles", for: .insights)
            }
            Tab(value: .giving) {
                GivingView(model: giving, credentials: credentials)
            } label: {
                tabLabel("Giving", systemImage: "heart", for: .giving)
            }
            Tab(value: .email) {
                EmailView(model: email)
            } label: {
                tabLabel("Email", systemImage: "envelope", for: .email)
            }
            Tab(value: .more) {
                MoreView(credentials: credentials, onDisconnect: onDisconnect)
            } label: {
                tabLabel("More", systemImage: "ellipsis", for: .more)
            }
        }
        .tint(Color.compassTeal)
    }

    private func tabLabel(_ title: String, systemImage: String, for tab: AppTab) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(uiImage: TabIcon.image(systemImage, color: selection == tab ? .compassTeal : .compassSecondaryText))
        }
    }
}

/// The iOS tab bar always swaps SF Symbols for their filled versions and colors
/// unselected tabs itself. The comps want grey outlines, so each icon is drawn
/// into a plain picture in the exact color, which the tab bar leaves alone.
private enum TabIcon {
    static func image(_ systemName: String, color: Color) -> UIImage {
        let configuration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        guard let symbol = UIImage(systemName: systemName, withConfiguration: configuration)?
            .withTintColor(UIColor(color), renderingMode: .alwaysOriginal)
        else { return UIImage() }
        let picture = UIGraphicsImageRenderer(size: symbol.size).image { _ in
            symbol.draw(at: .zero)
        }
        return picture.withRenderingMode(.alwaysOriginal)
    }
}
