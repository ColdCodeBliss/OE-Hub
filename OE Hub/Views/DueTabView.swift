import SwiftUI
import SwiftData
import UserNotifications

struct DueTabView: View {
    @Binding var newTaskDescription: String
    @Binding var newDueDate: Date
    @Binding var isCompletedSectionExpanded: Bool // reserved for future expand/collapse

    var job: Job

    @Environment(\.modelContext) private var modelContext
    @State private var showAddDeliverableForm = false
    @State private var showCompletedDeliverables = false
    @State private var deliverableToDeletePermanently: Deliverable? = nil
    @State private var selectedDeliverable: Deliverable? = nil
    @State private var showColorPicker = false
    @State private var showReminderPicker = false

    // Computed once per render; avoids repeating filter logic and keeps indices consistent
    private var activeDeliverables: [Deliverable] {
        job.deliverables
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        VStack(spacing: 16) {
            Button { showAddDeliverableForm = true } label: {
                Text("Add Deliverable")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.opacity(0.8))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            if showAddDeliverableForm {
                deliverableForm
            }

            deliverablesList

            if !completedDeliverables.isEmpty {
                Button(action: { showCompletedDeliverables = true }) {
                    HStack {
                        Text("Completed Deliverables")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.blue)
                }
                .padding()
                .sheet(isPresented: $showCompletedDeliverables) {
                    completedDeliverablesView
                }
            }
        }
        .background(Gradient(colors: [.blue, .purple]).opacity(0.1))
        .onAppear {
            showAddDeliverableForm = false
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                if granted { print("Notification permission granted") }
            }
        }
        .alert("Confirm Permanent Deletion", isPresented: Binding(
            get: { deliverableToDeletePermanently != nil },
            set: { if !$0 { deliverableToDeletePermanently = nil } }
        )) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Permanently", role: .destructive) {
                if let deliverable = deliverableToDeletePermanently {
                    // Permanently delete and clean notifications
                    modelContext.delete(deliverable)
                    try? modelContext.save()
                    removeAllNotifications(for: deliverable)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(
                selectedItem: Binding(
                    get: { selectedDeliverable },
                    set: { selectedDeliverable = $0 as? Deliverable }
                ),
                isPresented: $showColorPicker
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showReminderPicker) {
            ReminderPickerView(selectedDeliverable: $selectedDeliverable, isPresented: $showReminderPicker)
                .presentationDetents([.medium])
        }
    }

    var completedDeliverables: [Deliverable] {
        job.deliverables.filter { $0.isCompleted }
    }

    // MARK: - Add Form

    @ViewBuilder
    private var deliverableForm: some View {
        VStack {
            Text("Add Deliverable")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            TextField("Task Description", text: $newTaskDescription)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            DatePicker("Due Date", selection: $newDueDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .padding(.horizontal)

            HStack {
                Button(action: { showAddDeliverableForm = false }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.trailing)

                Button {
                    let newDeliverable = Deliverable(taskDescription: newTaskDescription, dueDate: newDueDate)
                    job.deliverables.append(newDeliverable)
                    newTaskDescription = ""
                    newDueDate = Date()
                    try? modelContext.save()
                    showAddDeliverableForm = false
                } label: {
                    Text("Add")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(newTaskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Active List

    @ViewBuilder
    private var deliverablesList: some View {
        List {
            activeDeliverablesSection
        }
        .scrollContentBackground(.hidden)
        .animation(.spring(duration: 0.3), value: job.deliverables)
    }

    @ViewBuilder
    private var activeDeliverablesSection: some View {
        Section(header: Text("Active Deliverables")) {
            ForEach(activeDeliverables) { deliverable in
                HStack {
                    VStack(alignment: .leading) {
                        Text(deliverable.taskDescription)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        DatePicker("Due", selection: Binding(
                            get: { deliverable.dueDate },
                            set: { newValue in
                                deliverable.dueDate = newValue
                                try? modelContext.save()
                                updateNotifications(for: deliverable)
                            }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        selectedDeliverable = deliverable
                        showReminderPicker = true
                    } label: {
                        Image(systemName: "bell")
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(readableForeground(on: color(for: deliverable.colorCode)))
                    .accessibilityLabel("Set reminders")
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color(for: deliverable.colorCode))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        deliverable.isCompleted = true
                        deliverable.completionDate = Date()
                        try? modelContext.save()
                        removeAllNotifications(for: deliverable)
                    } label: {
                        Label("Mark Complete", systemImage: "checkmark")
                    }
                    .tint(.green)

                    Button {
                        selectedDeliverable = deliverable
                        showColorPicker = true
                    } label: {
                        Label("Change Color", systemImage: "paintbrush")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        // Remove from job and clear notifications
                        if let idx = job.deliverables.firstIndex(of: deliverable) {
                            let removed = job.deliverables.remove(at: idx)
                            try? modelContext.save()
                            removeAllNotifications(for: removed)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                // FIX: Offsets refer to activeDeliverables, not job.deliverables.
                let toRemove = offsets.compactMap { activeDeliverables[safe: $0] }
                for d in toRemove {
                    if let idx = job.deliverables.firstIndex(of: d) {
                        let removed = job.deliverables.remove(at: idx)
                        removeAllNotifications(for: removed)
                    }
                }
                try? modelContext.save()
            }
        }
    }

    // MARK: - Completed Sheet

    @ViewBuilder
    private var completedDeliverablesView: some View {
        NavigationStack {
            List {
                ForEach(completedDeliverables) { deliverable in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(deliverable.taskDescription)
                            .font(.headline)

                        Text("Completed: \(formattedDate(deliverable.completionDate ?? Date()))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color(for: deliverable.colorCode))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deliverableToDeletePermanently = deliverable
                        } label: {
                            Label("Total Deletion", systemImage: "trash.fill")
                        }
                    }
                }
            }
            .navigationTitle("Completed Deliverables")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showCompletedDeliverables = false }
                }
            }
        }
    }
}

// MARK: - Notification Utilities

fileprivate func updateNotifications(for deliverable: Deliverable) {
    removeAllNotifications(for: deliverable) // clear any previous identifiers

    guard !deliverable.reminderOffsets.isEmpty else { return }

    let content = UNMutableNotificationContent()
    content.title = "Deliverable Reminder"
    content.body = "\(deliverable.taskDescription) is due on \(formattedDate(deliverable.dueDate))"
    content.sound = UNNotificationSound.default

    let idPrefix = String(describing: deliverable.persistentModelID)
    for offset in deliverable.reminderOffsets {
        if let triggerDate = calculateTriggerDate(for: offset, dueDate: deliverable.dueDate),
           triggerDate > Date() {
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "\(idPrefix)-\(offset)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                }
            }
        }
    }
}

fileprivate func removeAllNotifications(for deliverable: Deliverable) {
    let idPrefix = String(describing: deliverable.persistentModelID)
    // Remove any pending requests whose identifier starts with this prefix
    UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
        let ids = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(idPrefix + "-") }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

fileprivate func calculateTriggerDate(for offset: String, dueDate: Date) -> Date? {
    let calendar = Calendar.current
    switch offset.lowercased() {
    case "2weeks": return calendar.date(byAdding: .day, value: -14, to: dueDate)
    case "1week":  return calendar.date(byAdding: .day, value: -7,  to: dueDate)
    case "2days":  return calendar.date(byAdding: .day, value: -2,  to: dueDate)
    case "dayof":  return dueDate
    default:       return nil
    }
}

// Single, reusable date formatter helper (avoid duplicate declarations)
fileprivate func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM/dd/yyyy"
    return formatter.string(from: date)
}

// MARK: - Safe indexing helper
fileprivate extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
