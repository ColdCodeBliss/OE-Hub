import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(filter: #Predicate<Job> { !$0.isDeleted }) private var jobs: [Job]
    @Query(filter: #Predicate<Job> { $0.isDeleted }) private var deletedJobs: [Job]
    @Environment(\.modelContext) private var modelContext
    @State private var isRenaming = false
    @State private var jobToRename: Job?
    @State private var newJobTitle = ""
    @State private var showJobHistory = false
    @State private var jobToDeletePermanently: Job? = nil
    @State private var selectedJob: Job? = nil
    @State private var showColorPicker = false

    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(jobs) { job in
                        NavigationLink(destination: JobDetailView(job: job)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(job.title)
                                    .font(.headline)
                                Text("Created: \(job.creationDate, format: .dateTime)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(activeItemsCount(job)) active items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .background(Color.yellow.opacity(0.3)) // Diagnostic: Highlight the text area
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(color(for: job.colorCode))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .swipeActions(edge: .leading) {
                            Button(action: {
                                jobToRename = job
                                newJobTitle = job.title
                                isRenaming = true
                            }) {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                            Button(action: {
                                selectedJob = job
                                showColorPicker = true
                            }) {
                                Label("Change Color", systemImage: "paintbrush")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                job.isDeleted = true
                                job.deletionDate = Date()
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteJob)
                }
                .navigationTitle("WorkForge Stack")
                .toolbar {
                    Button("Add Job", systemImage: "plus") { addJob() }
                }
                .scrollContentBackground(.hidden)
                .background(Gradient(colors: [.blue, .purple]).opacity(0.1))
                .alert("Rename Job", isPresented: $isRenaming) {
                    TextField("New Title", text: $newJobTitle)
                    Button("Cancel", role: .cancel) {
                        isRenaming = false
                        jobToRename = nil
                        newJobTitle = ""
                    }
                    Button("Save") {
                        if let job = jobToRename {
                            job.title = newJobTitle
                            try? modelContext.save()
                        }
                        isRenaming = false
                        jobToRename = nil
                        newJobTitle = ""
                    }
                }
                if !deletedJobs.isEmpty {
                    Button(action: { showJobHistory = true }) {
                        HStack {
                            Text("Job History")
                                .font(.subheadline)
                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.blue)
                    }
                    .padding()
                    .sheet(isPresented: $showJobHistory) {
                        NavigationView {
                            List {
                                ForEach(deletedJobs) { job in
                                    VStack(alignment: .trailing) {
                                        Text(job.title)
                                            .font(.headline)
                                        Text("Deleted: \(job.deletionDate ?? Date(), format: .dateTime)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            jobToDeletePermanently = job
                                        } label: {
                                            Label("Total Deletion", systemImage: "trash.fill")
                                        }
                                    }
                                }
                            }
                            .navigationTitle("Job History")
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showJobHistory = false
                                    }
                                }
                            }
                        }
                    }
                    .alert("Confirm Permanent Deletion", isPresented: Binding(
                        get: { jobToDeletePermanently != nil },
                        set: { if !$0 { jobToDeletePermanently = nil } }
                    )) {
                        Button("Cancel", role: .cancel) { }
                        Button("Delete Permanently", role: .destructive) {
                            if let job = jobToDeletePermanently {
                                modelContext.delete(job)
                                try? modelContext.save()
                            }
                        }
                    } message: {
                        Text("This action cannot be undone.")
                    }
                }
            }
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(selectedItem: Binding(
                get: { selectedJob },
                set: { if let job = $0 as? Job {
                    selectedJob = job
                    job.colorCode = job.colorCode // Force refresh by reassigning
                    try? modelContext.save()
                } }
            ), isPresented: $showColorPicker)
                .presentationDetents([.medium])
        }
    }

    private func addJob() {
        let jobCount = jobs.count + 1
        let newJob = Job(title: "Job \(jobCount)")
        modelContext.insert(newJob)
        // Force refresh to ensure new job is visible
        do {
            try modelContext.save()
        } catch {
            print("Error saving new job: \(error)")
        }
    }

    private func deleteJob(at offsets: IndexSet) {
        for offset in offsets {
            let job = jobs[offset]
            job.isDeleted = true
            job.deletionDate = Date()
        }
        try? modelContext.save()
    }

    private func color(for colorCode: String?) -> Color {
        switch colorCode?.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        default: return .gray
        }
    }

    private func activeItemsCount(_ job: Job) -> Int {
        let activeDeliverables = job.deliverables.filter { !$0.isCompleted }.count
        let activeChecklistItems = job.checklistItems.filter { !$0.isCompleted }.count
        print("Job: \(job.title), Active Deliverables: \(activeDeliverables), Active Checklist Items: \(activeChecklistItems)") // Diagnostic print
        return activeDeliverables + activeChecklistItems
    }
}

#Preview {
    HomeView()
        .modelContainer(for: Job.self, inMemory: true)
}
