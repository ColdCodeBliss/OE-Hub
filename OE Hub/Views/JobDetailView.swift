import SwiftUI
import SwiftData

struct JobDetailView: View {
    // State that drives child tabs
    @State private var newTaskDescription: String = ""
    @State private var newDueDate: Date = Date()
    @State private var newChecklistItem: String = ""
    @State private var isCompletedSectionExpanded: Bool = false

    enum DetailTab: Hashable { case due, checklist, mindmap, notes, info }
    @State private var selection: DetailTab = .due

    // Triggers for top-right "+" buttons
    @State private var addDeliverableTrigger: Int = 0
    @State private var addNoteTrigger: Int = 0
    @State private var addChecklistTrigger: Int = 0

    // NEW: GitHub browser sheet flag
    @State private var showGitHubBrowser: Bool = false

    var job: Job

    var body: some View {
        content
            .navigationTitle(job.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { trailingButton }
            }
            // Present the GitHub repo browser
            .sheet(isPresented: $showGitHubBrowser) {
                GitHubBrowserView()
            }
    }

    // MARK: - Split main content

    @ViewBuilder
    private var content: some View {
        TabView(selection: $selection) {
            dueTab
            checklistTab
            mindmapTab
            notesTab
            infoTab
        }
    }

    // MARK: - Individual tabs

    private var dueTab: some View {
        DueTabView(
            newTaskDescription: $newTaskDescription,
            newDueDate: $newDueDate,
            isCompletedSectionExpanded: $isCompletedSectionExpanded,
            addDeliverableTrigger: $addDeliverableTrigger,
            job: job
        )
        .tabItem { Label("Due", systemImage: "calendar") }
        .tag(DetailTab.due)
    }

    private var checklistTab: some View {
        ChecklistsTabView(
            newChecklistItem: $newChecklistItem,
            addChecklistTrigger: $addChecklistTrigger,
            job: job
        )
        .tabItem { Label("Checklist", systemImage: "checkmark.square") }
        .tag(DetailTab.checklist)
    }

    private var mindmapTab: some View {
        MindMapTabView(job: job)
            .tabItem { Label("Mind Map", systemImage: "point.topleft.down.curvedto.point.bottomright.up") }
            .tag(DetailTab.mindmap)
    }

    private var notesTab: some View {
        NotesTabView(
            addNoteTrigger: $addNoteTrigger,
            job: job
        )
        .tabItem { Label("Notes", systemImage: "note.text") }
        .tag(DetailTab.notes)
    }

    private var infoTab: some View {
        InfoTabView(job: job)
            .tabItem { Label("Info", systemImage: "info.circle") }
            .tag(DetailTab.info)
    }

    // MARK: - Trailing toolbar button

    @ViewBuilder
    private var trailingButton: some View {
        switch selection {
        case .due:
            Button("Add Deliverable", systemImage: "plus") { addDeliverableTrigger &+= 1 }
                .accessibilityLabel("Add Deliverable")
        case .notes:
            Button("Add Note", systemImage: "plus") { addNoteTrigger &+= 1 }
                .accessibilityLabel("Add Note")
        case .checklist:
            Button("Add Item", systemImage: "plus") { addChecklistTrigger &+= 1 }
                .accessibilityLabel("Add Checklist Item")
        case .info:
            // NEW: GitHub button (uses a safe SF Symbol; swap to an asset if you add one)
            Button("GitHub", systemImage: "link") {
                showGitHubBrowser = true
            }
            .accessibilityLabel("Open GitHub Browser")
        default:
            EmptyView()
        }
    }
}
