//
//  CompassWidget.swift
//  CompassWidget
//
//  Home Screen widget: supporters (small), plus the period's other numbers (medium).
//  It only draws what the app saved (WidgetSnapshot); it never talks to Engaging
//  Networks itself and never sees the token.
//

import SwiftUI
import WidgetKit

struct PulseEntry: TimelineEntry {
    let date: Date
    /// Nil until the app has loaded numbers once.
    let snapshot: WidgetSnapshot?
}

struct PulseProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        // The widget gallery shows made-up numbers rather than an empty card.
        completion(PulseEntry(date: .now, snapshot: context.isPreview ? .sample : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        // The app asks for a redraw whenever it saves new numbers; this is only a fallback.
        let entry = PulseEntry(date: .now, snapshot: WidgetSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(6 * 3_600))))
    }
}

struct CompassWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CompassPulse", provider: PulseProvider()) { entry in
            PulseWidgetView(entry: entry)
                .containerBackground(Color.white, for: .widget)
        }
        .configurationDisplayName("Pulse")
        .description("Your supporters and how the latest period went.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct PulseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry

    var body: some View {
        if let snapshot = entry.snapshot, let headline = snapshot.items.first {
            HStack(alignment: .top, spacing: 14) {
                headlineColumn(headline, snapshot: snapshot)
                if family == .systemMedium {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(snapshot.items.dropFirst().prefix(3), id: \.title) { item in
                            row(item)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .foregroundStyle(Palette.text)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.title3)
                    .foregroundStyle(Palette.teal)
                Text("Open Compass to load your numbers.")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// The first number (supporters), big.
    private func headlineColumn(_ item: WidgetSnapshot.Item, snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
            Text(item.value)
                .font(.system(.title, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let change = item.change {
                changeBadge(change, isGood: item.isGood)
            }
            Spacer(minLength: 0)
            Text(snapshot.periodTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.teal)
            Text("Updated \(snapshot.updatedAt.formatted(.dateTime.month(.abbreviated).day()))")
                .font(.caption2)
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private func row(_ item: WidgetSnapshot.Item) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.title)
                .font(.caption2)
                .foregroundStyle(Palette.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(item.value)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let change = item.change {
                    Text(change)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(color(isGood: item.isGood))
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The ▲/▼ glyph is part of the text, so good or bad never rests on color alone.
    private func changeBadge(_ text: String, isGood: Bool?) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color(isGood: isGood))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isGood == false ? Palette.orangeTint : Palette.tealTint, in: .capsule)
    }

    private func color(isGood: Bool?) -> Color {
        switch isGood {
        case true?: Palette.teal
        case false?: Palette.orange
        case nil: Palette.secondaryText
        }
    }
}

/// The app's colors (Compass/App/Theme.swift); the widget can't see that file.
private enum Palette {
    static let teal = Color(red: 0x0E / 255, green: 0x5E / 255, blue: 0x6F / 255)
    static let tealTint = Color(red: 0xE4 / 255, green: 0xEF / 255, blue: 0xED / 255)
    static let orange = Color(red: 0x9A / 255, green: 0x43 / 255, blue: 0x09 / 255)
    static let orangeTint = Color(red: 0xFB / 255, green: 0xED / 255, blue: 0xE3 / 255)
    static let text = Color(red: 0x16 / 255, green: 0x18 / 255, blue: 0x1D / 255)
    static let secondaryText = Color(red: 0x5F / 255, green: 0x61 / 255, blue: 0x68 / 255)
}

#Preview(as: .systemSmall) {
    CompassWidget()
} timeline: {
    PulseEntry(date: .now, snapshot: .sample)
    PulseEntry(date: .now, snapshot: nil)
}

#Preview(as: .systemMedium) {
    CompassWidget()
} timeline: {
    PulseEntry(date: .now, snapshot: .sample)
}
