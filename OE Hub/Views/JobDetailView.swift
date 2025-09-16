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

    // Sheets
    @State private var showGitHubBrowser: Bool = false
    @State private var showConfluenceSheet: Bool = false   // ← NEW

    var job: Job

    var body: some View {
        content
            .navigationTitle(job.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { trailingButton }
            }
            // GitHub browser (namespaced by this Job’s key)
            .sheet(isPresented: $showGitHubBrowser) {
                GitHubBrowserView(recentKey: "recentRepos.\(job.repoBucketKey)")
            }
            
            // Confluence links (per-job key; up to 5)
            .sheet(isPresented: $showConfluenceSheet) {
                ConfluenceLinksView(
                    storageKey: "confluenceLinks.\(job.repoBucketKey)",
                    maxLinks: 5
                )
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

    // MARK: - Trailing toolbar button(s)

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
            // Confluence (left) + GitHub (right)
            HStack(spacing: 14) {
                Button(action: { showConfluenceSheet = true }) {
                    Image("Confluence_icon")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .accessibilityLabel("Open Confluence")
                }

                Button(action: { showGitHubBrowser = true }) {
                    Image("github")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .accessibilityLabel("Open GitHub Browser")
                }
            }

        default:
            EmptyView()
        }
    }
}
