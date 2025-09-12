import SwiftUI
import SwiftData

struct NotesTabView: View {
    @Environment(\.modelContext) private var modelContext

    // Editor state
    @State private var isAddingNote = false
    @State private var isEditingNote = false
    @State private var newNoteContent = ""
    @State private var newNoteSummary = ""
    @State private var selectedNote: Note? = nil

    // Rich text buffer (non-Beta sheet + Beta panel)
    @State private var editingAttributed: NSAttributedString = NSAttributedString(string: "")
    @State private var selectionRange: NSRange = NSRange(location: 0, length: 0)

    // Color picker state
    @State private var editingColorIndex: Int = 0

    // Style toggles
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false

    // Parent-driven trigger for the nav-bar “+”
    @Binding var addNoteTrigger: Int

    var job: Job

    // MARK: - Precomputed constants
    private let colors: [Color] = [.red, .blue, .green, .orange, .yellow, .purple, .brown, .teal]
    private let gridColumns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]

    private var sortedNotes: [Note] {
        let notes: [Note] = job.notes
        return notes.sorted { (a: Note, b: Note) in a.creationDate > b.creationDate }
    }

    private var nextColorIndex: Int {
        let used: Set<Int> = Set(job.notes.map { $0.colorIndex })
        for i in 0..<colors.count { if !used.contains(i) { return i } }
        return job.notes.count % colors.count
    }

    // MARK: - View

    var body: some View {
        ScrollView {
            makeGrid(notes: sortedNotes)
                .padding()
        }
        .sheet(isPresented: nonBetaSheetIsPresented) { nonBetaSheet }
        .overlay { betaOverlay }
        .navigationTitle("Notes")
        .animation(.default, value: job.notes.count)
        .onChange(of: addNoteTrigger) { _, _ in prepareNewNote() }
    }

    // MARK: - Builders

    @ViewBuilder
    private func makeGrid(notes: [Note]) -> some View {
        let columns: [GridItem] = gridColumns
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(notes) { (note: Note) in
                noteTile(for: note)
                    .onTapGesture { openEditor(for: note) }
            }
        }
    }

    private var nonBetaSheetIsPresented: Binding<Bool> {
        Binding(
            get: { (isAddingNote || isEditingNote) && !isBetaGlassEnabled },
            set: { if !$0 { dismissEditor() } }
        )
    }

    // Non-Beta rich-text sheet editor
    private var nonBetaSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Summary (short description)", text: $newNoteSummary)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                RichTextEditor(text: $editingAttributed, selectedRange: $selectionRange)
                    .frame(minHeight: 220)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                Picker("Color", selection: $editingColorIndex) {
                    ForEach(0..<colors.count, id: \.self) { (index: Int) in
                        Text(colorName(for: index)).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                HStack {
                    Button("Cancel") { dismissEditor() }
                        .foregroundStyle(.red)

                    Button("Save") {
                        saveNote(attributed: editingAttributed)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green.opacity(0.8))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(
                        newNoteSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        editingAttributed.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
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

    // ✅ Beta glass floating panel editor — fixed to use attributed text
    @ViewBuilder
    private var betaOverlay: some View {
        if (isAddingNote || isEditingNote) && isBetaGlassEnabled {
            NoteEditorPanel(
                isPresented: Binding(
                    get: { isAddingNote || isEditingNote },
                    set: { if !$0 { dismissEditor() } }
                ),
                title: (selectedNote != nil ? "Edit Note" : "New Note"),
                summary: $newNoteSummary,
                attributedText: $editingAttributed,     // rich text binding
                colors: colors,
                colorIndex: $editingColorIndex,
                onCancel: { dismissEditor() },
                onSave: {
                    saveNote(attributed: editingAttributed)          // persist rich text
                },
                onDelete: (selectedNote == nil ? nil : {
                    // Delete only available when editing an existing note
                    guard let note = selectedNote else { return }
                    if let idx = job.notes.firstIndex(of: note) {
                        job.notes.remove(at: idx)
                    }
                    modelContext.delete(note)
                    try? modelContext.save()
                    dismissEditor()
                })
            )
            .zIndex(2)
        } else {
            EmptyView()
        }
    }


    // MARK: - Tiles

    private func noteTile(for note: Note) -> some View {
        let idx: Int = safeIndex(note.colorIndex)
        let tint: Color = colors[idx]
        let fg: Color = .black
        let isGlass: Bool = (isLiquidGlassEnabled || isBetaGlassEnabled)
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
        .background(tileBackground(tint: tint, radius: radius))
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
                    .glassEffect(.regular.tint(tint.opacity(0.55)),
                                 in: .rect(cornerRadius: radius))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), .clear],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .blendMode(.plusLighter)
            }
        } else if isLiquidGlassEnabled {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.opacity(0.55)))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.18), .clear],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading))
                        .blendMode(.plusLighter)
                )
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.gradient)
        }
    }

    // MARK: - Actions

    private func openEditor(for note: Note) {
        selectedNote = note
        newNoteContent = note.content
        newNoteSummary = note.summary
        editingColorIndex = safeIndex(note.colorIndex)
        editingAttributed = note.attributed
        isEditingNote = true
    }

    private func prepareNewNote() {
        selectedNote = nil
        newNoteContent = ""
        newNoteSummary = ""
        editingColorIndex = nextColorIndex
        editingAttributed = NSAttributedString(string: "")
        isAddingNote = true
    }

    /// Save helper. If `attributed` is provided, persist full rich text via `Note.attributed`.
    private func saveNote(attributed: NSAttributedString?) {
        let trimmedSummary: String = newNoteSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let plainBody: String = (attributed?.string ?? newNoteContent)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSummary.isEmpty, !plainBody.isEmpty else { return }

        if let note = selectedNote {
            note.summary = trimmedSummary
            note.colorIndex = safeIndex(editingColorIndex)
            if let rich = attributed {
                note.attributed = rich
            } else {
                note.content = plainBody
            }
        } else {
            let idx = safeIndex(editingColorIndex)
            let new = Note(content: plainBody, summary: trimmedSummary, colorIndex: idx)
            if let rich = attributed {
                new.attributed = rich
            }
            job.notes.append(new)
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
        selectionRange = NSRange(location: 0, length: 0)
        editingAttributed = NSAttributedString(string: "")
    }

    // MARK: - Helpers

    private func colorName(for index: Int) -> String {
        switch safeIndex(index) {
        case 0: return "Red"
        case 1: return "Blue"
        case 2: return "Green"
        case 3: return "Orange"
        case 4: return "Yellow"
        case 5: return "Purple"
        case 6: return "Brown"
        case 7: return "Teal"
        default: return "Green"
        }
    }

    private func safeIndex(_ idx: Int) -> Int {
        guard !colors.isEmpty else { return 0 }
        return ((idx % colors.count) + colors.count) % colors.count
    }
}
