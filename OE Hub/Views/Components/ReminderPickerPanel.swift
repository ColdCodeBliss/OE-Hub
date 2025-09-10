//
//  ReminderPickerPanel.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/10/25.
//


import SwiftUI
import SwiftData
import UserNotifications

struct ReminderPickerPanel: View {
    @Binding var selectedDeliverable: Deliverable?
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    @State private var selection: Set<Deliverable.ReminderOffset> = []

    // Options shown to the user
    private let options: [(Deliverable.ReminderOffset, String)] = [
        (.twoWeeks, "2 Weeks Before"),
        (.oneWeek,  "1 Week Before"),
        (.twoDays,  "2 Days Before"),
        (.dayOf,    "Day Of")
    ]

    var body: some View {
        ZStack {
            // Dim backdrop – tap outside to dismiss
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Floating glass panel
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Text("Reminders")
                        .font(.headline)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)

                Divider().opacity(0.15)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let d = selectedDeliverable {
                            // Due date card
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Due Date")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(d.dueDate, format: .dateTime.month().day().year().hour().minute())
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(innerCardBackground(corner: 14))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Toggle cards
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reminders")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            VStack(spacing: 10) {
                                ForEach(options, id: \.0) { opt in
                                    Toggle(isOn: binding(for: opt.0)) {
                                        Text(opt.1)
                                    }
                                    .toggleStyle(.switch)
                                }
                            }
                            .padding(12)
                            .background(innerCardBackground(corner: 14))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        if let d = selectedDeliverable, !selection.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Will notify at")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(selection).sorted(by: sortOffsets), id: \.self) { off in
                                        if let when = triggerDate(for: off, dueDate: d.dueDate) {
                                            Text("\(label(for: off)): \(when.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(innerCardBackground(corner: 14))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        HStack(spacing: 12) {
                            Button("Cancel") { dismiss() }
                                .foregroundStyle(.red)

                            Button("Save") {
                                save()
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(saveEnabled ? Color.green.opacity(0.85) : Color.gray.opacity(0.4))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .disabled(!saveEnabled)
                        }
                        .padding(.top, 6)
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: 520)
            .background(panelBackground) // glass bubble background
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
            .padding(.horizontal, 16)
            .transition(.scale.combined(with: .opacity))
        }
        .onAppear {
            if let d = selectedDeliverable {
                selection = d.reminderSet
            }
        }
    }

    private var saveEnabled: Bool {
        guard let _ = selectedDeliverable else { return false }
        return true
    }

    private func dismiss() {
        isPresented = false
    }

    // MARK: - Backgrounds

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func innerCardBackground(corner: CGFloat) -> some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.clear, in: .rect(cornerRadius: corner))
        } else {
            RoundedRectangle(cornerRadius: corner).fill(.ultraThinMaterial)
        }
    }

    // MARK: - Bindings

    private func binding(for offset: Deliverable.ReminderOffset) -> Binding<Bool> {
        Binding(
            get: { selection.contains(offset) },
            set: { newValue in
                if newValue { selection.insert(offset) } else { selection.remove(offset) }
            }
        )
    }

    // MARK: - Actions

    private func save() {
        guard let d = selectedDeliverable else { return }
        d.reminderSet = selection
        try? modelContext.save()
        rescheduleNotifications(for: d)
    }

    // MARK: - Notifications

    private func rescheduleNotifications(for deliverable: Deliverable) {
        removeAllNotifications(for: deliverable)
        guard !selection.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Deliverable Reminder"
        content.body  = "\(deliverable.taskDescription) is due on \(formatDate(deliverable.dueDate))"
        content.sound = .default

        let idPrefix = String(describing: deliverable.persistentModelID)
        for off in selection {
            if let date = triggerDate(for: off, dueDate: deliverable.dueDate), date > Date() {
                let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let req = UNNotificationRequest(identifier: "\(idPrefix)-\(off.rawValue)", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(req) { err in
                    if let err = err { print("Notification error:", err.localizedDescription) }
                }
            }
        }
    }

    private func removeAllNotifications(for deliverable: Deliverable) {
        let idPrefix = String(describing: deliverable.persistentModelID)
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(idPrefix + "-") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private func triggerDate(for offset: Deliverable.ReminderOffset, dueDate: Date) -> Date? {
        switch offset {
        case .twoWeeks: return Calendar.current.date(byAdding: .day, value: -14, to: dueDate)
        case .oneWeek:  return Calendar.current.date(byAdding: .day, value: -7,  to: dueDate)
        case .twoDays:  return Calendar.current.date(byAdding: .day, value: -2,  to: dueDate)
        case .dayOf:    return dueDate
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd/yyyy"
        return f.string(from: date)
    }

    private func label(for offset: Deliverable.ReminderOffset) -> String {
        switch offset {
        case .twoWeeks: return "2 Weeks Before"
        case .oneWeek:  return "1 Week Before"
        case .twoDays:  return "2 Days Before"
        case .dayOf:    return "Day Of"
        }
    }

    private func sortOffsets(_ a: Deliverable.ReminderOffset, _ b: Deliverable.ReminderOffset) -> Bool {
        let order: [Deliverable.ReminderOffset: Int] = [.twoWeeks: 0, .oneWeek: 1, .twoDays: 2, .dayOf: 3]
        return (order[a] ?? 0) < (order[b] ?? 0)
    }
}
