import SwiftUI
import SwiftData

struct HomeView: View {
    // Queries (initialized in init to ease the type checker)
    @Query private var jobs: [Job]
    @Query private var deletedJobs: [Job]

    @Environment(\.modelContext) private var modelContext

    // UI State
    @State private var isRenaming = false
    @State private var jobToRename: Job?
    @State private var newJobTitle = ""

    @State private var showJobHistory = false
    @State private var jobToDeletePermanently: Job?

    @State private var selectedJob: Job?
    @State private var showColorPicker = false
    @State private var showSettings = false

    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    private let heroLogoHeight: CGFloat = 120   // logo size
    private let heroTopOffset: CGFloat = 0      // distance from button row
    private let gapBelowLogo: CGFloat = 0       // tiny gap above first card
    private let logoYOffset: CGFloat = -69      // negative lifts the logo closer to the buttons
    private let listGapBelowLogo: CGFloat = -25 // tiny space between logo and first card

    // MARK: - Init: move #Predicate here (reduces compiler load)
    init() {
        _jobs = Query(
            filter: #Predicate<Job> { !$0.isDeleted },
            sort: [SortDescriptor(\.creationDate, order: .forward)]
        )
        _deletedJobs = Query(
            filter: #Predicate<Job> { $0.isDeleted },
            sort: [SortDescriptor(\.deletionDate, order: .reverse)]
        )
    }

    var body: some View {
        NavigationStack {
            VStack {
                jobList
                jobHistoryButton
            }
            // Push content down just enough so it sits under the overlayed logo
            .padding(.top, max(0, heroLogoHeight + heroTopOffset + listGapBelowLogo + logoYOffset))

            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }

            // Draw the logo on top (doesn't take layout space)
            .overlay(alignment: .top) {
                HeroLogoRow(height: heroLogoHeight)
                    .padding(.top, heroTopOffset)   // distance from button row
                    .padding(.horizontal, 16)
                    .offset(y: logoYOffset)         // lift the logo up (negative values)
                    .allowsHitTesting(false)
                    .zIndex(1)
            }

            .background(Gradient(colors: [.blue, .purple]).opacity(0.1))

            // sheets & alerts (unchanged except Settings presentation split below)
            .sheet(isPresented: $showJobHistory) {
                JobHistorySheetView(
                    deletedJobs: deletedJobs,
                    jobToDeletePermanently: $jobToDeletePermanently,
                    onDone: { showJobHistory = false }
                )
            }

            // ❗️Settings: present as a normal sheet when Beta Glass is OFF
            .sheet(isPresented: Binding(
                get: { showSettings && !isBetaGlassEnabled },
                set: { if !$0 { showSettings = false } }
            )) {
                SettingsView()
            }

            .sheet(isPresented: $showColorPicker) {
                ColorPickerView(
                    selectedItem: selectedItemBinding,
                    isPresented: $showColorPicker
                )
                .presentationDetents([.medium])
            }
            .alert("Rename Job", isPresented: $isRenaming) { renameAlertButtons }
            .alert("Confirm Permanent Deletion", isPresented: deletionAlertFlag) {
                deletionAlertButtons
            } message: {
                Text("This action cannot be undone.")
            }

            // ❗️Settings: present as a floating glass panel when Beta Glass is ON
            .overlay {
                if showSettings && isBetaGlassEnabled {
                    SettingsPanel(isPresented: $showSettings)
                        .zIndex(2) // keep above everything else
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    // MARK: - Subviews

    private var jobList: some View {
        List {
            ForEach(jobs, id: \.persistentModelID) { (job: Job) in
                NavigationLink(destination: JobDetailView(job: job)) {
                    JobRowView(job: job) // separate file
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button { startRenaming(job) } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.blue)

                    Button {
                        selectedJob = job
                        showColorPicker = true
                    } label: {
                        Label("Change Color", systemImage: "paintbrush")
                    }
                    .tint(.green)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { softDelete(job) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                // ⬇️ Optional tweaks for the floating “bubble” look
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteJob)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var jobHistoryButton: some View {
        if !deletedJobs.isEmpty {
            Button { showJobHistory = true } label: {
                HStack {
                    Text("Job History").font(.subheadline)
                    Image(systemName: "chevron.right").font(.subheadline)
                }
                .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button("Settings") { showSettings = true }
                Button("Option 1") { /* future */ }
                Button("Option 2") { /* future */ }
            } label: {
                Label("Menu", systemImage: "line.horizontal.3")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Add Job", systemImage: "plus") { addJob() }
        }
    }

    // MARK: - Alerts (extracted buttons/bindings)

    private var deletionAlertFlag: Binding<Bool> {
        Binding(
            get: { jobToDeletePermanently != nil },
            set: { if !$0 { jobToDeletePermanently = nil } }
        )
    }

    @ViewBuilder
    private var renameAlertButtons: some View {
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

    @ViewBuilder
    private var deletionAlertButtons: some View {
        Button("Cancel", role: .cancel) { }
        Button("Delete Permanently", role: .destructive) {
            if let job = jobToDeletePermanently {
                modelContext.delete(job)
                try? modelContext.save()
            }
        }
    }

    // MARK: - Bindings

    private var selectedItemBinding: Binding<Any?> {
        Binding<Any?>(
            get: { selectedJob },
            set: { newValue in
                if let job = newValue as? Job {
                    selectedJob = job
                    // "Ping" change to refresh views that read colorCode.
                    job.colorCode = job.colorCode
                    try? modelContext.save()
                } else {
                    selectedJob = nil
                }
            }
        )
    }

    // MARK: - Actions

    private func startRenaming(_ job: Job) {
        jobToRename = job
        newJobTitle = job.title
        isRenaming = true
    }

    private func softDelete(_ job: Job) {
        job.isDeleted = true
        job.deletionDate = Date()
        try? modelContext.save()
    }

    private func addJob() {
        let jobCount = jobs.count + 1
        let newJob = Job(title: "Job \(jobCount)")
        modelContext.insert(newJob)
        do { try modelContext.save() } catch {
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
}
