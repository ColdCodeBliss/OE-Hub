//
// ColorPickerView.swift
// OE Hub
//
// Created by Ryan Bliss on 9/5/25.
//
import SwiftUI
import SwiftData

struct ColorPickerView: View {
    @Binding var selectedItem: Any?
    @Binding var isPresented: Bool

    // Keep your available palette; reuses Utilities.color(for:)
    let colors: [String] = ["red", "blue", "green", "yellow", "orange", "purple", "pink", "teal", "gray"]

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Color")
                    .font(.title2).bold()

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 10) {
                    ForEach(colors, id: \.self) { colorName in
                        Button {
                            apply(colorName)
                            isPresented = false
                        } label: {
                            Circle()
                                .fill(color(for: colorName)) // from Utilities.swift
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            isCurrentlySelected(colorName) ? Color.primary : .black.opacity(0.2),
                                            lineWidth: isCurrentlySelected(colorName) ? 2 : 1
                                        )
                                )
                                .accessibilityLabel(Text(colorName.capitalized))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Color Picker")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func apply(_ colorName: String) {
        if let job = selectedItem as? Job {
            job.colorCode = colorName
        } else if let checklistItem = selectedItem as? ChecklistItem {
            // NOTE: Your app uses color names for priority; we keep that behavior.
            // If you decide to restrict to {Green, Yellow, Red}, clamp here.
            checklistItem.priority = colorName.capitalized
        } else if let deliverable = selectedItem as? Deliverable {
            deliverable.colorCode = colorName
        }
        try? modelContext.save()
    }

    private func isCurrentlySelected(_ colorName: String) -> Bool {
        if let job = selectedItem as? Job {
            return (job.colorCode?.lowercased() ?? "") == colorName
        } else if let checklistItem = selectedItem as? ChecklistItem {
            return checklistItem.priority.lowercased() == colorName
        } else if let deliverable = selectedItem as? Deliverable {
            return (deliverable.colorCode?.lowercased() ?? "") == colorName
        }
        return false
    }
}
