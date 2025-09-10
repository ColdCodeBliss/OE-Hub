import SwiftUI
import SwiftData

struct JobDetailView: View {
    // State that drives child tabs
    @State private var newTaskDescription: String = ""
    @State private var newDueDate: Date = Date()
    @State private var newChecklistItem: String = ""
    @State private var isCompletedSectionExpanded: Bool = false

    var job: Job

    var body: some View {
        // No nested NavigationStack: rely on the parent stack (prevents double stacks)
        TabView {
            DueTabView(
                newTaskDescription: $newTaskDescription,
                newDueDate: $newDueDate,
                isCompletedSectionExpanded: $isCompletedSectionExpanded,
                job: job
            )
            .tabItem { Label("Due", systemImage: "calendar") }

            ChecklistsTabView(
                newChecklistItem: $newChecklistItem,
                job: job
            )
            .tabItem { Label("Checklist", systemImage: "checkmark.square") }
            
            MindMapTabView(job: job)
                .tabItem { Label("Mind Map", systemImage: "point.topleft.down.curvedto.point.bottomright.up") }

            NotesTabView(job: job)
                .tabItem { Label("Notes", systemImage: "note.text") }

            InfoTabView(job: job)
                .tabItem { Label("Info", systemImage: "info.circle") }
        }
        .navigationTitle(job.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct JobDetailView_Previews: PreviewProvider {
    static var previews: some View {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: Job.self, Deliverable.self, ChecklistItem.self, Note.self,
                configurations: config
            )
            return NavigationStack {
                JobDetailView(job: Job(title: "Preview Job"))
            }
            .modelContainer(container)
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}
