import SwiftUI
import SwiftData

struct NotesTabView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingNote = false
    @State private var isEditingNote = false
    @State private var newNoteContent = ""
    @State private var newNoteSummary = ""
    @State private var selectedNote: Note? = nil

    // New: drive the picker even when creating a note (selectedNote == nil)
    @State private var editingColorIndex: Int = 0

    // Toggle comes from SettingsView ("Liquid Glass")
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false

    var job: Job

    // Keep your palette but ensure safe indexing everywhere
    private let colors: [Color] = [.red, .blue, .green, .orange, .yellow, .purple, .pink, .teal]

    private var nextColorIndex: Int {
        let usedIndices = Set(job.notes.map { $0.colorIndex })
        for index in 0..<colors.count {
            if !usedIndices.contains(index) { return index }
        }
        return job.notes.count % colors.count
    }

    var body: some View {
        VStack(spacing: 16) {
            Button {
                // Prepare a clean editor state
                selectedNote = nil
                newNoteContent = ""
                newNoteSummary = ""
                editingColorIndex = nextColorIndex
                isAddingNote = true
            } label: {
                Text("New Note")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.opacity(0.8))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    // Sort newest first for predictable ordering
                    ForEach(job.notes.sorted(by: { $0.creationDate > $1.creationDate })) { note in
                        noteTile(for: note)
                            .onTapGesture {
                                selectedNote = note
                                newNoteContent = note.content
                                newNoteSummary = note.summary
                                // Bind picker to existing color
                                editingColorIndex = safeIndex(note.colorIndex)
                                isEditingNote = true
                            }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: Binding(
            get: { isAddingNote || isEditingNote },
            set: { if !$0 { dismissEditor() } }
        )) { noteEditor }
        .navigationTitle("Notes")
        .animation(.default, value: job.notes.count)
    }

    // MARK: - Editor

    @ViewBuilder
    private var noteEditor: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Summary (short description)", text: $newNoteSummary)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                TextEditor(text: $newNoteContent)
                    .frame(height: 200)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Picker("Color", selection: $editingColorIndex) {
                    ForEach(0..<colors.count, id: \.self) { index in
                        Text(colorName(for: index)).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                HStack {
                    Button("Cancel") { dismissEditor() }
                        .foregroundStyle(.red)

                    Button("Save") { saveNote() }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || newNoteSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .navigationTitle(selectedNote != nil ? "Edit Note" : "New Note")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismissEditor() }
                }
            }
        }
    }

    // MARK: - Tiles

    private func noteTile(for note: Note) -> some View {
        let idx = safeIndex(note.colorIndex)
        let tint = colors[idx]
        let fg = readableForeground(on: tint)

        return VStack(alignment: .leading, spacing: 8) {
            Text(note.summary)
                .font(.headline)
                .foregroundStyle(fg)
            Text(note.creationDate, style: .date)
                .font(.caption)
                .foregroundStyle(fg.opacity(0.85))
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(tileBackground(tint: tint))              // ← conditional glass vs solid
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(tileStroke)                                  // subtle rim light
        .shadow(radius: isLiquidGlassEnabled ? 2 : 5)         // lighter shadow when glassy
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func tileBackground(tint: Color) -> some View {
        if isLiquidGlassEnabled {
            // SDK-safe “glass-like” look: material base + tinted glaze + soft highlight
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(tint.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
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
            // 🔧 Fix: return a View, not a ShapeStyle
            RoundedRectangle(cornerRadius: 16)
                .fill(tint.gradient)
        }
    }

    private var tileStroke: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(isLiquidGlassEnabled ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
    }

    // MARK: - Helpers

    private func saveNote() {
        let trimmedSummary = newNoteSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSummary.isEmpty, !trimmedContent.isEmpty else { return }

        if let note = selectedNote {
            note.summary = trimmedSummary
            note.content = trimmedContent
            note.colorIndex = safeIndex(editingColorIndex)
        } else {
            let newNote = Note(content: trimmedContent, summary: trimmedSummary, colorIndex: safeIndex(editingColorIndex))
            job.notes.append(newNote)
        }
        try? modelContext.save()
        dismissEditor()
    }

    private func dismissEditor() {
        isAddingNote = false
        isEditingNote = false
        newNoteContent = ""
        newNoteSummary = ""
        selectedNote = nil
    }

    private func colorName(for index: Int) -> String {
        switch safeIndex(index) {
        case 0: return "Red"
        case 1: return "Blue"
        case 2: return "Green"
        case 3: return "Orange"
        case 4: return "Yellow"
        case 5: return "Purple"
        case 6: return "Pink"
        case 7: return "Teal"
        default: return "Green"
        }
    }

    private func safeIndex(_ idx: Int) -> Int {
        guard !colors.isEmpty else { return 0 }
        return ((idx % colors.count) + colors.count) % colors.count
    }
}
/*
#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Job.self, Deliverable.self, ChecklistItem.self, Note.self, configurations: config)
        return NotesTabView(job: Job(title: "Preview Job"))
            .modelContainer(container)
    } catch {
        fatalError("Failed to create preview container: \(error)")
    }
}
*/
