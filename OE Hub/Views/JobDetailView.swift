import SwiftUI
import SwiftData

struct JobDetailView: View {
    // State that drives child tabs
    @State private var newTaskDescription: String = ""
    @State private var newDueDate: Date = Date()
    @State private var newChecklistItem: String = ""
    @State private var isCompletedSectionExpanded: Bool = false

    private enum DetailTab: Hashable { case due, checklist, mindmap, notes, info }
    @State private var selection: DetailTab = .due

    // Triggers for top-right "+" buttons
    @State private var addDeliverableTrigger: Int = 0
    @State private var addNoteTrigger: Int = 0
    @State private var addChecklistTrigger: Int = 0


    var job: Job

    var body: some View {
        TabView(selection: $selection) {
            DueTabView(
                newTaskDescription: $newTaskDescription,
                newDueDate: $newDueDate,
                isCompletedSectionExpanded: $isCompletedSectionExpanded,
                addDeliverableTrigger: $addDeliverableTrigger,   // ← trigger last
                job: job,                                 // ← job first
            )
            .tabItem { Label("Due", systemImage: "calendar") }
            .tag(DetailTab.due)

            ChecklistsTabView(
                newChecklistItem: $newChecklistItem,
                addChecklistTrigger: $addChecklistTrigger,   // ← NEW
                job: job
            )
            .tabItem { Label("Checklist", systemImage: "checkmark.square") }
            .tag(DetailTab.checklist)

            MindMapTabView(job: job)
                .tabItem { Label("Mind Map", systemImage: "point.topleft.down.curvedto.point.bottomright.up") }
                .tag(DetailTab.mindmap)

            NotesTabView(
                addNoteTrigger: $addNoteTrigger,   // ← trigger first
                job: job                            // ← job second
            )
            .tabItem { Label("Notes", systemImage: "note.text") }
            .tag(DetailTab.notes)

            InfoTabView(job: job)
                .tabItem { Label("Info", systemImage: "info.circle") }
                .tag(DetailTab.info)
        }
        .navigationTitle(job.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                switch selection {
                case .due:
                    Button("Add Deliverable", systemImage: "plus") {
                        addDeliverableTrigger &+= 1
                    }
                    .accessibilityLabel("Add Deliverable")

                case .notes:
                    Button("Add Note", systemImage: "plus") {
                        addNoteTrigger &+= 1
                    }
                    .accessibilityLabel("Add Note")

                case .checklist:
                    Button("Add Item", systemImage: "plus") {
                        addChecklistTrigger &+= 1
                    }
                    .accessibilityLabel("Add Checklist Item")

                default:
                    EmptyView()
                }
            }
        }

    }
}
