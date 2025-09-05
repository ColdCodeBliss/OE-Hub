import SwiftUI
import SwiftData

struct ColorPickerView: View {
    @Binding var selectedItem: Any?
    @Binding var isPresented: Bool
    let colors: [String] = ["red", "blue", "green", "yellow", "orange", "purple", "pink", "teal", "gray"]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Select Color")
                    .font(.title2)
                    .bold()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 10) {
                    ForEach(colors, id: \.self) { colorName in
                        Button(action: {
                            if let checklistItem = selectedItem as? ChecklistItem {
                                checklistItem.priority = colorName.capitalized
                                try? modelContext.save()
                            } else if let deliverable = selectedItem as? Deliverable {
                                deliverable.colorCode = colorName
                                try? modelContext.save()
                            }
                            isPresented = false
                        }) {
                            Circle()
                                .fill(color(for: colorName))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 1)
                                        .opacity((selectedItem as? ChecklistItem)?.priority.lowercased() == colorName || (selectedItem as? Deliverable)?.colorCode == colorName ? 1 : 0)
                                )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Color Picker")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func color(for colorCode: String) -> Color {
        switch colorCode.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "gray": return .gray
        default: return .gray
        }
    }
}