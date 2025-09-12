import SwiftUI
import UIKit

struct NoteEditorPanel: View {
    @Binding var isPresented: Bool

    let title: String
    @Binding var summary: String

    // Edits the caller’s attributed text directly
    @Binding var attributedText: NSAttributedString
    @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)

    let colors: [Color]
    @Binding var colorIndex: Int

    var onCancel: () -> Void
    var onSave: () -> Void

    // ⬅️ NEW: provide this only when editing to show the trash button
    var onDelete: (() -> Void)? = nil

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
                    Button { dismiss() } label: {
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

                        // Formatting toolbar
                        HStack(spacing: 10) {
                            formatButton(system: "bold", label: "Bold") { toggleBold() }
                            formatButton(system: "underline", label: "Underline") { toggleUnderline() }
                            formatButton(system: "strikethrough", label: "Strikethrough") { toggleStrikethrough() }
                            formatButton(system: "list.bullet", label: "Bulleted List") { insertBulletedList() }
                            Spacer()
                            colorMenu
                        }

                        // Editor
                        RichTextEditorKit(attributedText: $attributedText, selectedRange: $selectedRange)
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(innerCardBackground(corner: 12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(16)
                }

                // Footer actions
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

                    // ⬅️ NEW: Trashcan appears only when onDelete is present (i.e., editing)
                    if onDelete != nil {
                        Button(role: .destructive) {
                            onDelete?()
                            dismiss()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 40, height: 40)
                        }
                        .accessibilityLabel("Delete Note")
                        .background(Color.red.opacity(0.9))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16)
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
        attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func dismiss() { isPresented = false }

    // MARK: - Backgrounds

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
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

    // MARK: - Toolbar helpers

    private func formatButton(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var colorMenu: some View {
        Menu {
            ForEach(0..<colors.count, id: \.self) { idx in
                Button { colorIndex = idx } label: {
                    HStack {
                        Circle().fill(colors[idx]).frame(width: 14, height: 14)
                        Text(colorName(for: idx))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(colors[safeIndex(colorIndex)]).frame(width: 16, height: 16)
                Text("Color").font(.subheadline)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
        }
    }

    // MARK: - Formatting actions

    private func toggleBold() {
        guard attributedText.length > 0 else { return }
        let range = normalizedSelection()
        let m = NSMutableAttributedString(attributedString: attributedText)
        m.enumerateAttribute(.font, in: range, options: []) { value, subRange, _ in
            let base = (value as? UIFont) ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
            let hasBold = base.fontDescriptor.symbolicTraits.contains(.traitBold)
            let newDescriptor = base.fontDescriptor.withSymbolicTraits(
                hasBold ? base.fontDescriptor.symbolicTraits.subtracting(.traitBold)
                        : base.fontDescriptor.symbolicTraits.union(.traitBold)
            )
            let newFont = newDescriptor.flatMap { UIFont(descriptor: $0, size: base.pointSize) } ?? base
            m.addAttribute(.font, value: newFont, range: subRange)
        }
        attributedText = m
    }

    private func toggleUnderline() {
        guard attributedText.length > 0 else { return }
        let range = normalizedSelection()
        let m = NSMutableAttributedString(attributedString: attributedText)
        m.enumerateAttribute(.underlineStyle, in: range, options: []) { value, subRange, _ in
            let isOn = (value as? Int ?? 0) != 0
            if isOn { m.removeAttribute(.underlineStyle, range: subRange) }
            else { m.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: subRange) }
        }
        attributedText = m
    }

    private func toggleStrikethrough() {
        guard attributedText.length > 0 else { return }
        let range = normalizedSelection()
        let m = NSMutableAttributedString(attributedString: attributedText)
        m.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, subRange, _ in
            let isOn = (value as? Int ?? 0) != 0
            if isOn { m.removeAttribute(.strikethroughStyle, range: subRange) }
            else { m.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: subRange) }
        }
        attributedText = m
    }

    private func insertBulletedList() {
        let ns = attributedText.string as NSString
        let pr = ns.paragraphRange(for: normalizedSelection())
        let m = NSMutableAttributedString(attributedString: attributedText)

        let paraText = ns.substring(with: pr)
        let lines = paraText.split(maxSplits: .max, omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        var cursor = pr.location
        for line in lines {
            let lineStr = String(line)
            let lineNS = lineStr as NSString
            let lineRange = NSRange(location: cursor, length: lineNS.length)

            if !lineStr.hasPrefix("• ") && !lineStr.hasPrefix("- ") {
                m.insert(NSAttributedString(string: "• "), at: lineRange.location)
                cursor += 2 + lineNS.length
            } else {
                cursor += lineNS.length
            }
            if cursor < ns.length, ns.substring(with: NSRange(location: cursor, length: 1)) == "\n" {
                cursor += 1
            }
        }
        attributedText = m
    }

    private func normalizedSelection() -> NSRange {
        var r = selectedRange
        if r.location == NSNotFound { r = NSRange(location: 0, length: 0) }
        if r.length == 0 {
            let ns = attributedText.string as NSString
            r = ns.paragraphRange(for: r)
        }
        let maxLen = max(0, attributedText.length)
        let loc = min(max(0, r.location), maxLen)
        let len = min(max(0, r.length), maxLen - loc)
        return NSRange(location: loc, length: len)
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
        default: return "Color"
        }
    }

    private func safeIndex(_ idx: Int) -> Int {
        return ((idx % colors.count) + colors.count) % colors.count
    }
}

// MARK: - UITextView-backed rich editor
struct RichTextEditorKit: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var selectedRange: NSRange

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.alwaysBounceVertical = true
        tv.delegate = context.coordinator
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.adjustsFontForContentSizeCategory = true

        // allow inline styling operations to apply
        tv.allowsEditingTextAttributes = true

        tv.attributedText = attributedText
        tv.selectedRange = selectedRange
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
        if uiView.selectedRange.location != selectedRange.location || uiView.selectedRange.length != selectedRange.length {
            uiView.selectedRange = selectedRange
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditorKit
        init(_ parent: RichTextEditorKit) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            let newValue: NSAttributedString = textView.attributedText ?? NSAttributedString(string: "")
            if parent.attributedText != newValue {
                DispatchQueue.main.async {
                    self.parent.attributedText = newValue
                }
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let newRange = textView.selectedRange
            if self.parent.selectedRange.location != newRange.location ||
               self.parent.selectedRange.length   != newRange.length {
                DispatchQueue.main.async {
                    self.parent.selectedRange = newRange
                }
            }
        }
    }
}
