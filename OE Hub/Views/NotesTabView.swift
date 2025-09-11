import SwiftUI
import SwiftData

struct NotesTabView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingNote = false
    @State private var isEditingNote = false
    @State private var newNoteContent = ""
    @State private var newNoteSummary = ""
    @State private var selectedNote: Note? = nil

    // Drive the picker even when creating a note (selectedNote == nil)
    @State private var editingColorIndex: Int = 0

    // Toggles from Settings
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false   // Classic
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false   // Real (iOS 18+)

    // ⬅️ NEW: parent-driven trigger for the nav-bar “+” button
    @Binding var addNoteTrigger: Int

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
        // No big button—just the grid
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
        // OLD editor sheet shown only when Beta is OFF
        .sheet(isPresented: Binding(
            get: { (isAddingNote || isEditingNote) && !isBetaGlassEnabled },
            set: { if !$0 { dismissEditor() } }
        )) { noteEditor }

        // NEW floating editor panel when Beta is ON
        .overlay {
            if (isAddingNote || isEditingNote) && isBetaGlassEnabled {
                NoteEditorPanel(
                    isPresented: Binding(
                        get: { isAddingNote || isEditingNote },
                        set: { if !$0 { dismissEditor() } }
                    ),
                    title: (selectedNote != nil ? "Edit Note" : "New Note"),
                    summary: $newNoteSummary,
                    content: $newNoteContent,
                    colors: colors,
                    colorIndex: $editingColorIndex,
                    onCancel: { dismissEditor() },
                    onSave: { saveNote() }
                )
                .zIndex(2)
            }
        }
        .navigationTitle("Notes")
        .animation(.default, value: job.notes.count)

        // ⬅️ React to the parent’s nav-bar “+”
        .onChange(of: addNoteTrigger) { _, _ in
            // Prepare a clean editor state
            selectedNote = nil
            newNoteContent = ""
            newNoteSummary = ""
            editingColorIndex = nextColorIndex
            isAddingNote = true
        }
    }

    // MARK: - Editor (used only for the non-Beta sheet)

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
        let fg: Color = .black   // always black

        let isGlass = isLiquidGlassEnabled || isBetaGlassEnabled
        let radius: CGFloat = 16

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
        .background(tileBackground(tint: tint, radius: radius))      // ← conditional (Beta/Classic/Solid)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(isGlass ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: (isGlass ? Color.black.opacity(0.25) : Color.black.opacity(0.15)),
                radius: (isGlass ? 14 : 5), x: 0, y: (isGlass ? 8 : 0))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func tileBackground(tint: Color, radius: CGFloat) -> some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear
                    .glassEffect(
                        .regular
                            .tint(tint.opacity(0.55)),
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
                .fill(tint.gradient)
        }
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
