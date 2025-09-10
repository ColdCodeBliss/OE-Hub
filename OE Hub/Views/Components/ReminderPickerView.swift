//
//  ReminderPickerView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/8/25.
//


import SwiftUI
import SwiftData
import UserNotifications

struct ReminderPickerView: View {
    @Binding var selectedDeliverable: Deliverable?
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var selection: Set<Deliverable.ReminderOffset> = []

    // Shown in the list (maps to your Deliverable.ReminderOffset enum)
    private let options: [(Deliverable.ReminderOffset, String)] = [
        (.twoWeeks, "2 Weeks Before"),
        (.oneWeek,  "1 Week Before"),
        (.twoDays,  "2 Days Before"),
        (.dayOf,    "Day Of")
    ]

    var body: some View {
        NavigationStack {
            Form {
                if let d = selectedDeliverable {
                    Section("Due Date") {
                        Text(d.dueDate, format: .dateTime.month().day().year().hour().minute())
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Reminders") {
                    ForEach(options, id: \.0) { opt in
                        Toggle(isOn: binding(for: opt.0)) {
                            Text(opt.1)
                        }
                    }
                }

                if let d = selectedDeliverable, !selection.isEmpty {
                    Section("Will notify at") {
                        ForEach(Array(selection).sorted(by: sortOffsets), id: \.self) { off in
                            if let when = triggerDate(for: off, dueDate: d.dueDate) {
                                Text("\(label(for: off)): \(when.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.disabled(selectedDeliverable == nil)
                }
            }
            .onAppear {
                if let d = selectedDeliverable {
                    // Load existing selections from your typed wrapper
                    selection = d.reminderSet
                }
            }
        }
    }

    // MARK: - Actions

    private func save() {
        guard let d = selectedDeliverable else { return }
        d.reminderSet = selection                        // persist as strings under the hood
        try? modelContext.save()
        rescheduleNotifications(for: d)                  // schedule notifications now
        isPresented = false
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
/*
#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Job.self, Deliverable.self, configurations: config)
        let job = Job(title: "Preview")
        let d = Deliverable(taskDescription: "Write report", dueDate: Date().addingTimeInterval(86_400 * 7))
        job.deliverables.append(d)
        return ReminderPickerView(selectedDeliverable: .constant(d), isPresented: .constant(true))
            .modelContainer(container)
    } catch {
        fatalError("Preview container error: \(error)")
    }
}
*/
