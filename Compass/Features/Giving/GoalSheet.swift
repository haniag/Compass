//
//  GoalSheet.swift
//  Compass
//
//  Set, change or remove a donation page's fundraising goal. Engaging Networks has
//  no goals or deadlines, so they're entered here and kept on this iPhone.
//

import SwiftData
import SwiftUI

struct GoalSheet: View {
    let page: FollowedPage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var amount: Decimal?
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @FocusState private var amountFocused: Bool

    init(page: FollowedPage) {
        self.page = page
        _amount = State(initialValue: page.goalAmount)
        _hasDeadline = State(initialValue: page.goalDeadline != nil)
        // A new deadline starts a month out.
        _deadline = State(initialValue: page.goalDeadline
            ?? Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now)
    }

    private var canSave: Bool { (amount ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", value: $amount,
                              format: .currency(code: AccountSettings.reportingCurrency).precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .accessibilityLabel("Goal amount")
                } header: {
                    Text("Goal for \(page.name)")
                } footer: {
                    Text("Counted against everything this page has raised since it began.")
                }
                Section {
                    Toggle("Has a deadline", isOn: $hasDeadline)
                        .tint(Color.compassTeal)
                    if hasDeadline {
                        DatePicker("Last day", selection: $deadline, displayedComponents: .date)
                    }
                } footer: {
                    Text("With a deadline, Giving shows how much is needed each day to get there.")
                }
                if page.goalAmount != nil {
                    Section {
                        Button("Remove goal", role: .destructive) {
                            save(amount: nil, deadline: nil)
                        }
                    }
                }
            }
            .navigationTitle(page.goalAmount == nil ? "Set a goal" : "Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(amount: amount, deadline: hasDeadline ? Calendar.current.startOfDay(for: deadline) : nil)
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { amountFocused = page.goalAmount == nil }
        }
        .tint(Color.compassTeal)
    }

    private func save(amount: Decimal?, deadline: Date?) {
        page.goalAmount = amount
        page.goalDeadline = deadline
        try? modelContext.save()
        dismiss()
    }
}
