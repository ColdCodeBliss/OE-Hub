import SwiftUI
import SwiftData

struct ChecklistsTabView: View {
    @Binding var newChecklistItem: String
    var job: Job
    @Environment(\.modelContext) private var modelContext
    @State private var isCompletedSectionExpanded: Bool = false
    @State private var showAddChecklistForm: Bool = false
    @State private var selectedChecklistItem: ChecklistItem? = nil
    @State private var showColorPicker = false

    var body: some View {
        VStack(spacing: 16) {
            Button(action: { showAddChecklistForm = true }) {
                Text("Add Checklist Item")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.opacity(0.8))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            if showAddChecklistForm {
                checklistForm
            }

            checklistsList
        }
        .background(Gradient(colors: [.blue, .purple]).opacity(0.1))
        .onAppear {
            showAddChecklistForm = false
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(selectedItem: Binding(
                get: { selectedChecklistItem },
                set: { selectedChecklistItem = $0 as? ChecklistItem }
            ), isPresented: $showColorPicker)
                .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var checklistForm: some View {
        VStack {
            Text("Add Checklist Item")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            TextField("Item Description", text: $newChecklistItem)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            HStack {
                Button(action: {
                    showAddChecklistForm = false
                }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.trailing)

                Button(action: addChecklistItem) {
                    Text("Add")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(newChecklistItem.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var checklistsList: some View {
        List {
            Section(header: Text("Active Checklists")) {
                ForEach(job.checklistItems.filter { !$0.isCompleted }) { item in
                    HStack {
                        Circle()
                            .fill(priorityColor(for: item.priority))
                            .frame(width: 12, height: 12)
                        Text(item.title)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            item.isCompleted = true
                            item.completionDate = Date()
                            do {
                                try modelContext.save()
                            } catch {
                                print("Save error: \(error)")
                            }
                        } label: {
                            Label("Mark Complete", systemImage: "checkmark")
                        }
                        .tint(.green)
                        Button {
                            selectedChecklistItem = item
                            showColorPicker = true
                        } label: {
                            Label("Change Color", systemImage: "paintbrush")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            if let index = job.checklistItems.firstIndex(of: item) {
                                job.checklistItems.remove(at: index)
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("Save error: \(error)")
                                }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            if isCompletedSectionExpanded {
                Section(header: Text("Completed Checklists (\(job.checklistItems.filter { $0.isCompleted }.count))")
                    .font(.headline)) {
                    ForEach(job.checklistItems.filter { $0.isCompleted }) { item in
                        HStack {
                            Circle()
                                .fill(priorityColor(for: item.priority))
                                .frame(width: 12, height: 12)
                            Text(item.title)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formattedDate(item.completionDate ?? Date()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                item.isCompleted = false
                                item.completionDate = nil
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("Save error: \(error)")
                                }
                            } label: {
                                Label("Unmark", systemImage: "arrow.uturn.left")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                if let index = job.checklistItems.firstIndex(of: item) {
                                    job.checklistItems.remove(at: index)
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        print("Save error: \(error)")
                                    }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } else {
                Button(action: { isCompletedSectionExpanded.toggle() }) {
                    Text("Show Completed Checklists (\(job.checklistItems.filter { $0.isCompleted }.count))")
                        .font(.headline)
                }
            }
        }
        .listStyle(.plain)
        .listRowSeparator(.hidden)
    }

    private func addChecklistItem() {
        withAnimation {
            let newItem = ChecklistItem(title: newChecklistItem)
            job.checklistItems.append(newItem)
            newChecklistItem = ""
            do {
                try modelContext.save()
            } catch {
                print("Save error: \(error)")
            }
            showAddChecklistForm = false
        }
    }

    private func priorityColor(for priority: String) -> Color {
        switch priority.lowercased() {
        case "red": return .red
        case "yellow": return .yellow
        case "green": return .green
        default: return .green
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    ChecklistsTabView(
        newChecklistItem: .constant(""),
        job: Job(title: "Preview Job")
    )
    .modelContainer(for: [Job.self, ChecklistItem.self], inMemory: true)
}
