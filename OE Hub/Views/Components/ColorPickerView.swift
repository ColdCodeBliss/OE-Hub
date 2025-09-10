//
//  ColorPickerView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/5/25.
//

import SwiftUI
import SwiftData

struct ColorPickerView: View {
    @Binding var selectedItem: Any?
    @Binding var isPresented: Bool

    // Keep your available palette; reuses Utilities.color(for:)
    let colors: [String] = ["red", "blue", "green", "yellow", "orange", "purple", "pink", "teal", "gray"]

    @Environment(\.modelContext) private var modelContext
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Color")
                    .font(.title2).bold()   // ← fixed extra parenthesis

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 10) {
                    ForEach(colors, id: \.self) { colorName in
                        let tint = color(for: colorName)
                        let isSelected = isCurrentlySelected(colorName)

                        Button {
                            apply(colorName)
                            isPresented = false
                        } label: {
                            chipView(tint: tint, isSelected: isSelected, colorName: colorName)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
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

    // MARK: - Chip View (SDK-safe “glassy” look without .glassEffect)

    @ViewBuilder
    private func chipView(tint: Color, isSelected: Bool, colorName: String) -> some View {
        // When “Liquid Glass” is enabled, use material + tint overlay to emulate a glass chip.
        let chip = Group {
            if isLiquidGlassEnabled {
                Circle()
                    .fill(.ultraThinMaterial)                  // blurred, glassy base
                    .overlay(Circle().fill(tint.opacity(0.65)))// tinted glaze
                    .overlay(                                   // subtle highlight for depth
                        Circle().fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.plusLighter)
                    )
            } else {
                // Original solid chip
                Circle().fill(tint)
            }
        }
        .frame(width: 40, height: 40)
        .overlay(
            Circle().stroke(
                isSelected ? Color.primary : Color.black.opacity(0.2),
                lineWidth: isSelected ? 2 : 1
            )
        )
        .accessibilityLabel(Text(colorName.capitalized))

        chip
    }

    // MARK: - Helpers

    private func apply(_ colorName: String) {
        if let job = selectedItem as? Job {
            job.colorCode = colorName
        } else if let checklistItem = selectedItem as? ChecklistItem {
            // NOTE: Your app uses color names for priority; we keep that behavior.
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
