import SwiftUI

struct NoteEditorPanel: View {
    @Binding var isPresented: Bool

    let title: String
    @Binding var summary: String
    @Binding var content: String

    let colors: [Color]
    @Binding var colorIndex: Int

    var onCancel: () -> Void
    var onSave: () -> Void

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    var body: some View {
        ZStack {
            // Dimmed backdrop; tap outside to dismiss
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Floating panel
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)

                Divider().opacity(0.15)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Summary
                        Group {
                            Text("Summary")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Short description", text: $summary)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Content
                        Group {
                            Text("Content")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextEditor(text: $content)
                                .frame(minHeight: 160)
                                .padding(8)
                                .background(innerCardBackground(corner: 12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Color – grid of dots (replaces Picker(.menu))
                        Group {
                            Text("Color")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            let columns = [GridItem(.adaptive(minimum: 44, maximum: 56), spacing: 10)]
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(colors.indices, id: \.self) { i in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            colorIndex = i
                                        }
                                    } label: {
                                        Circle()
                                            .fill(colors[i])
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(
                                                        i == colorIndex ? Color.primary : .black.opacity(0.2),
                                                        lineWidth: i == colorIndex ? 2 : 1
                                                    )
                                            )
                                            .accessibilityLabel(Text(colorName(for: i)))
                                            .accessibilityAddTraits(i == colorIndex ? .isSelected : [])
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 2)
                        }

                        // Actions
                        HStack(spacing: 12) {
                            Button("Cancel") { onCancel(); dismiss() }
                                .foregroundStyle(.red)

                            Button("Save") {
                                onSave()
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(saveEnabled ? Color.green.opacity(0.85) : Color.gray.opacity(0.4))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .disabled(!saveEnabled)
                        }
                        .padding(.top, 6)
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: 520)
            .background(panelBackground) // glass bubble
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
            .padding(.horizontal, 16)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var saveEnabled: Bool {
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func dismiss() {
        isPresented = false
    }

    // MARK: - Backgrounds

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            // If Beta unavailable, keep a premium material look
            RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func innerCardBackground(corner: CGFloat) -> some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.clear, in: .rect(cornerRadius: corner))
        } else {
            RoundedRectangle(cornerRadius: corner).fill(.ultraThinMaterial)
        }
    }

    private func colorName(for index: Int) -> String {
        switch index {
        case 0: return "Red"
        case 1: return "Blue"
        case 2: return "Green"
        case 3: return "Orange"
        case 4: return "Yellow"
        case 5: return "Purple"
        case 6: return "Pink"
        case 7: return "Teal"
        default: return "Color"
        }
    }
}
