import SwiftUI
import SwiftData
import UserNotifications

struct DueTabView: View {
    @Binding var newTaskDescription: String
    @Binding var newDueDate: Date
    @Binding var isCompletedSectionExpanded: Bool // reserved for future expand/collapse

    // ⬅️ NEW: driven by JobDetailView’s + button
    @Binding var addDeliverableTrigger: Int

    var job: Job

    @Environment(\.modelContext) private var modelContext
    @State private var showAddDeliverableForm = false
    @State private var showCompletedDeliverables = false
    @State private var deliverableToDeletePermanently: Deliverable? = nil
    @State private var selectedDeliverable: Deliverable? = nil
    @State private var showColorPicker = false
    @State private var showReminderPicker = false

    // Liquid Glass toggles
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false   // Classic (fallback)
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false       // Real Liquid Glass (iOS 18+)

    // Computed once per render; avoids repeating filter logic and keeps indices consistent
    private var activeDeliverables: [Deliverable] {
        job.deliverables
            .filter { !$0.isCompleted }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var body: some View {
        VStack(spacing: 16) {
            // ⬇️ Removed the old big “Add Deliverable” bubble button

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
            }
        }
        .background(Gradient(colors: [.blue, .purple]).opacity(0.1))
        .onAppear {
            showAddDeliverableForm = false
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                if granted { print("Notification permission granted") }
            }
        }
        // ⬅️ NEW: open the inline form whenever the parent bumps the trigger
        .onChange(of: addDeliverableTrigger) { _, _ in
            showAddDeliverableForm = true
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
        // Split: sheet vs floating panel for reminders
        .sheet(isPresented: Binding(
            get: { showReminderPicker && !isBetaGlassEnabled },
            set: { if !$0 { showReminderPicker = false } }
        )) {
            ReminderPickerView(selectedDeliverable: $selectedDeliverable, isPresented: $showReminderPicker)
                .presentationDetents([.medium])
        }
        .overlay {
            if showReminderPicker && isBetaGlassEnabled {
                ReminderPickerPanel(
                    selectedDeliverable: $selectedDeliverable,
                    isPresented: $showReminderPicker
                )
                .zIndex(3)
            }
        }

        // ✅ Completed Deliverables: sheet when Beta OFF
        .sheet(isPresented: Binding(
            get: { showCompletedDeliverables && !isBetaGlassEnabled },
            set: { if !$0 { showCompletedDeliverables = false } }
        )) {
            completedDeliverablesView
        }

        // ✅ Completed Deliverables: floating glass panel when Beta ON
        .overlay {
            if showCompletedDeliverables && isBetaGlassEnabled {
                CompletedDeliverablesPanel(
                    isPresented: $showCompletedDeliverables,
                    deliverableToDeletePermanently: $deliverableToDeletePermanently,
                    deliverables: completedDeliverables
                )
                .zIndex(4)
            }
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
                let tint = color(for: deliverable.colorCode)
                let radius: CGFloat = 12
                let isGlass = isLiquidGlassEnabled || isBetaGlassEnabled
                let hasReminders = !deliverable.reminderOffsets.isEmpty   // or !deliverable.reminderSet.isEmpty

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(deliverable.taskDescription)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        // Keep "Due" and the compact chips on ONE ROW
                        HStack(spacing: 8) {
                            Text("Due")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { deliverable.dueDate },
                                    set: { newValue in
                                        deliverable.dueDate = newValue
                                        try? modelContext.save()
                                        updateNotifications(for: deliverable)
                                    }
                                ),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .fixedSize()
                            .accessibilityLabel("Due date")
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        selectedDeliverable = deliverable
                        showReminderPicker = true
                    } label: {
                        Image(systemName: "bell")
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(hasReminders ? Color.black : Color.white) // white = no reminder, black = has reminder
                    .accessibilityLabel("Set reminders")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(rowBackground(tint: tint, radius: radius)) // glass/solid
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(isGlass ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: isGlass ? .black.opacity(0.25) : .black.opacity(0.15),
                        radius: isGlass ? 14 : 5, x: 0, y: isGlass ? 8 : 0)

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

                // Float over the list background
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                // Offsets refer to activeDeliverables, not job.deliverables.
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

    // MARK: - Completed Sheet (standard sheet version)

    @ViewBuilder
    private var completedDeliverablesView: some View {
        NavigationStack {
            List {
                ForEach(completedDeliverables) { deliverable in
                    let tint = color(for: deliverable.colorCode)
                    let radius: CGFloat = 12
                    let isGlass = isLiquidGlassEnabled || isBetaGlassEnabled

                    VStack(alignment: .leading, spacing: 6) {
                        Text(deliverable.taskDescription)
                            .font(.headline)

                        Text("Completed: \(formattedDate(deliverable.completionDate ?? Date()))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(rowBackground(tint: tint, radius: radius))
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(isGlass ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
                    )
                    .shadow(color: isGlass ? .black.opacity(0.25) : .black.opacity(0.15),
                            radius: isGlass ? 14 : 5, x: 0, y: isGlass ? 8 : 0)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deliverableToDeletePermanently = deliverable
                        } label: {
                            Label("Total Deletion", systemImage: "trash.fill")
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Completed Deliverables")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showCompletedDeliverables = false }
                }
            }
        }
    }

    // MARK: - Background selector

    @ViewBuilder
    private func rowBackground(tint: Color, radius: CGFloat) -> some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            // Real Liquid Glass (iOS 18+): glass bubble with gentle highlight
            ZStack {
                Color.clear
                    .glassEffect(
                        .regular.tint(tint.opacity(0.50)),
                        in: .rect(cornerRadius: radius)
                    )
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            }
        } else if isLiquidGlassEnabled {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(tint.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.plusLighter)
                )
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint)
        }
    }
}

// MARK: - Floating Completed Deliverables Panel (Beta glass)
private struct CompletedDeliverablesPanel: View {
    @Binding var isPresented: Bool
    @Binding var deliverableToDeletePermanently: Deliverable?

    let deliverables: [Deliverable]

    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false

    var body: some View {
        ZStack {
            // Dim
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 12) {
                HStack {
                    Text("Completed Deliverables")
                        .font(.headline)
                    Spacer()
                    Button {
                        withAnimation { isPresented = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 28, height: 28)
                    }
                    .background(closeBackground)
                    .clipShape(Circle())
                }

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(deliverables) { d in
                            let tint = color(for: d.colorCode)
                            let radius: CGFloat = 12
                            let isGlass = isLiquidGlassEnabled || isBetaGlassEnabled

                            VStack(alignment: .leading, spacing: 6) {
                                Text(d.taskDescription)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("Completed: \(formattedDate(d.completionDate ?? Date()))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(rowBackgroundPanel(tint: tint, radius: radius))
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .stroke(isGlass ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
                            )
                            .shadow(color: isGlass ? .black.opacity(0.25) : .black.opacity(0.15),
                                    radius: isGlass ? 14 : 5, x: 0, y: isGlass ? 8 : 0)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deliverableToDeletePermanently = d
                                } label: {
                                    Label("Delete Permanently", systemImage: "trash fill")
                                }
                            }
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 560)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale))
    }

    // Panel backgrounds
    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.16), .clear],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .blendMode(.plusLighter)
            }
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var closeBackground: some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .circle)
        } else {
            Circle().fill(.ultraThinMaterial)
        }
    }

    // Row backgrounds inside the panel
    @ViewBuilder
    private func rowBackgroundPanel(tint: Color, radius: CGFloat) -> some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear
                    .glassEffect(.regular.tint(tint.opacity(0.5)), in: .rect(cornerRadius: radius))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .blendMode(.plusLighter)
            }
        } else if isLiquidGlassEnabled {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(tint.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .blendMode(.plusLighter)
                )
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint)
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
