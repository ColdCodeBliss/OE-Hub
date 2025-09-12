import SwiftUI
import SwiftData
import UIKit

struct MindMapTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false

    var job: Job

    private let canvasSize: CGFloat = 3000
    private var canvasCenter: CGPoint { CGPoint(x: canvasSize/2, y: canvasSize/2) }

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var selected: MindNode?

    @State private var viewSize: CGSize = .zero
    @State private var scaleBase: CGFloat = 1.0

    private let childRadius: CGFloat = 220
    private let nodeColorOptions: [String] = ["red","blue","green","yellow","orange","purple","brown","teal","gray"]

    @State private var showClearConfirm = false
    @State private var isTopToolbarCollapsed = false
    @State private var showAutoArrangeConfirm = false

    @FocusState private var focusedNodeID: UUID?

    private var isLandscape: Bool { viewSize.width > viewSize.height }
    private var slideDistance: CGFloat { isLandscape ? 156 : 94 }
    private var expandedTrailingPad: CGFloat { isLandscape ? -55 : 9 }
    private var collapsedTrailingPad: CGFloat { isLandscape ? 4 : 4 }

    // ✅ Share state: present sheet only when we have a URL
    private struct ShareItem: Identifiable { let id = UUID(); let url: URL }
    @State private var shareItem: ShareItem? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selected = nil
                        focusedNodeID = nil
                    }

                mapContent
                    .frame(width: canvasSize, height: canvasSize)
                    .offset(offset)
                    .scaleEffect(scale, anchor: .topLeading)
                    .gesture(panGesture.simultaneously(with: zoomGesture))
                    .animation(.interactiveSpring(), value: scale)
                    .animation(.interactiveSpring(), value: offset)
            }
            .onAppear {
                viewSize = geo.size
                ensureRoot()
                if let root = job.mindNodes.first(where: { $0.isRoot }) {
                    center(on: CGPoint(x: root.x, y: root.y))
                } else {
                    center(on: canvasCenter)
                }
            }
            .onChange(of: geo.size) { _, newSize in
                viewSize = newSize
            }
        }
        .navigationTitle("Mind Map")

        .safeAreaInset(edge: .bottom) {
            controlsBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }

        // Top-right overlay (wand, trash, share)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        isTopToolbarCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: isTopToolbarCollapsed ? "chevron.left" : "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .padding(6)
                .background(topButtonBackground)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                .accessibilityLabel(isTopToolbarCollapsed ? "Show tools" : "Hide tools")

                HStack(spacing: 6) {
                    Button { showAutoArrangeConfirm = true } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }

                    Button {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Clear Mind Map")

                    // ✅ Share (export PDF)
                    Button { shareMindMap() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Share Mind Map")
                }
                .padding(6)
                .background(topButtonBackground)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            }
            .offset(x: isTopToolbarCollapsed ? slideDistance : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isTopToolbarCollapsed)
            .padding(.trailing, isTopToolbarCollapsed ? collapsedTrailingPad : expandedTrailingPad)
            .padding(.top, 8)
        }

        // Glass confirmation overlay (unchanged)
        .overlay {
            if showAutoArrangeConfirm && (isBetaGlassEnabled || isLiquidGlassEnabled) {
                AutoArrangeConfirmPanel(
                    isPresented: $showAutoArrangeConfirm,
                    isBeta: isBetaGlassEnabled,
                    onConfirm: { autoArrangeTree() }
                )
                .zIndex(3)
            }
        }

        // Fallback system alert (unchanged)
        .alert(
            "Re-arrange Mind Map?",
            isPresented: Binding(
                get: { showAutoArrangeConfirm && !(isBetaGlassEnabled || isLiquidGlassEnabled) },
                set: { if !$0 { showAutoArrangeConfirm = false } }
            )
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Re-arrange", role: .destructive) { autoArrangeTree() }
        } message: {
            Text("This will re-arrange the entire map and is not reversible.")
        }

        // Clear alert (unchanged)
        .alert("Clear Mind Map?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) { clearMindMap() }
        } message: {
            Text("This will permanently delete all nodes. This action cannot be undone.")
        }

        // ✅ Present only when we actually have a URL to share
        .sheet(item: $shareItem, onDismiss: { shareItem = nil }) { item in
            ActivityView(activityItems: [item.url])
                .ignoresSafeArea()
        }
    }

    // MARK: - Live map (interactive)
    private var mapContent: some View {
        ZStack {
            // edges
            Canvas { ctx, _ in
                for node in job.mindNodes {
                    guard let parent = node.parent else { continue }
                    let p1 = CGPoint(x: parent.x, y: parent.y)
                    let p2 = CGPoint(x: node.x,   y: node.y)
                    var path = Path()
                    let mid = CGPoint(x: (p1.x + p2.x)/2, y: (p1.y + p2.y)/2)
                    path.move(to: p1)
                    path.addQuadCurve(to: p2, control: mid)
                    let stroke = StrokeStyle(lineWidth: 2, lineCap: .round)
                    ctx.stroke(path, with: .color(.primary.opacity(0.25)), style: stroke)
                }
            }

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    selected = nil
                    focusedNodeID = nil
                }

            // nodes
            ForEach(job.mindNodes) { node in
                NodeBubble(node: node,
                           isSelected: node.id == selected?.id,
                           glassOn: (isLiquidGlassEnabled || isBetaGlassEnabled),
                           focused: $focusedNodeID)
                    .position(x: node.x, y: node.y)
                    .highPriorityGesture(nodeDragGesture(for: node))
                    .onTapGesture { selected = node }
            }
        }
        .background(Color.clear)
        .clipped()
    }

    // MARK: - Snapshot map (read-only, used for PDF export)
    private var snapshotContent: some View {
        ZStack {
            Canvas { ctx, _ in
                for node in job.mindNodes {
                    guard let parent = node.parent else { continue }
                    let p1 = CGPoint(x: parent.x, y: parent.y)
                    let p2 = CGPoint(x: node.x,   y: node.y)
                    var path = Path()
                    let mid = CGPoint(x: (p1.x + p2.x)/2, y: (p1.y + p2.y)/2)
                    path.move(to: p1)
                    path.addQuadCurve(to: p2, control: mid)
                    let stroke = StrokeStyle(lineWidth: 2, lineCap: .round)
                    ctx.stroke(path, with: .color(.primary.opacity(0.25)), style: stroke)
                }
            }

            ForEach(job.mindNodes) { node in
                NodeBubbleSnapshot(node: node, glassOn: (isLiquidGlassEnabled || isBetaGlassEnabled))
                    .position(x: node.x, y: node.y)
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .background(Color.clear)
    }

    // MARK: - Bottom controls (unchanged)
    private var controlsBar: some View {
        HStack(spacing: 10) {
            Button { zoom(by: -0.15) } label: { controlIcon("minus.magnifyingglass") }
            Button { zoom(by:  0.15) } label: { controlIcon("plus.magnifyingglass") }
            Button { centerOnRoot() }   label: { controlIcon("target") }
            Button { addChild() }       label: { controlIcon("plus") }

            if let s = selected, !s.isRoot {
                Button(role: .destructive) { deleteSelected() } label: { controlIcon("trash") }
            }

            if let s = selected {
                Button { toggleComplete(s) } label: {
                    controlIcon(s.isCompleted ? "checkmark.circle.fill" : "circle")
                }

                Menu {
                    ForEach(nodeColorOptions, id: \.self) { code in
                        Button {
                            s.colorCode = code
                            try? modelContext.save()
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(color(for: code))
                                    .frame(width: 14, height: 14)
                                Text(code.capitalized)
                            }
                        }
                    }
                } label: {
                    controlIcon("paintpalette")
                }
            }
        }
        .padding(10)
        .background(controlsBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    @ViewBuilder private var controlsBackground: some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .capsule)
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder private var topButtonBackground: some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .capsule)
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder private func controlIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
    }

    // MARK: - Gestures / actions (unchanged)
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                offset = CGSize(width: offset.width + value.translation.width,
                                height: offset.height + value.translation.height)
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = clamp(scaleBase * value, min: 0.4, max: 3.0)
            }
            .onEnded { _ in
                scaleBase = clamp(scale, min: 0.4, max: 3.0)
            }
    }

    private func nodeDragGesture(for node: MindNode) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                node.x += Double(v.translation.width / scale)
                node.y += Double(v.translation.height / scale)
            }
            .onEnded { _ in try? modelContext.save() }
    }

    private func ensureRoot() {
        if job.mindNodes.contains(where: { $0.isRoot }) { return }
        let root = MindNode(title: job.title.isEmpty ? "Central Idea" : job.title,
                            x: Double(canvasCenter.x),
                            y: Double(canvasCenter.y),
                            colorCode: "teal",
                            isRoot: true)
        root.job = job
        job.mindNodes.append(root)
        try? modelContext.save()
        selected = root
    }

    private func centerOnRoot() {
        if let root = job.mindNodes.first(where: { $0.isRoot }) {
            center(on: CGPoint(x: root.x, y: root.y))
        }
    }

    private func center(on p: CGPoint) {
        guard viewSize != .zero else { return }
        withAnimation(.spring()) {
            let viewCenter = CGPoint(x: viewSize.width/2, y: viewSize.height/2)
            offset = CGSize(width: viewCenter.x / scale - p.x,
                            height: viewCenter.y / scale - p.y)
        }
    }

    private func addChild() {
        guard let anchor = selected ?? job.mindNodes.first(where: { $0.isRoot }) else { return }
        let count = max(0, anchor.children.count)
        let angle = CGFloat(count) * (.pi / 3.0)
        let dx = cos(angle) * childRadius
        let dy = sin(angle) * childRadius
        let child = MindNode(title: "New Node",
                             x: anchor.x + Double(dx),
                             y: anchor.y + Double(dy),
                             colorCode: anchor.colorCode ?? "teal")
        child.job = job
        child.parent = anchor
        anchor.children.append(child)
        job.mindNodes.append(child)
        try? modelContext.save()
        selected = child
    }

    private func deleteSelected() {
        guard let node = selected, !node.isRoot else { return }
        if let parent = node.parent {
            for c in node.children {
                c.parent = parent
                parent.children.append(c)
            }
        }
        modelContext.delete(node)
        try? modelContext.save()
        selected = nil
    }

    private func toggleComplete(_ node: MindNode) {
        node.isCompleted.toggle()
        try? modelContext.save()
    }

    private func zoom(by delta: CGFloat) {
        scale = clamp(scale + delta, min: 0.4, max: 3.0)
        scaleBase = scale
        if let focus = selected ?? job.mindNodes.first(where: { $0.isRoot }) {
            center(on: CGPoint(x: focus.x, y: focus.y))
        }
    }

    private func clearMindMap() {
        for n in job.mindNodes { modelContext.delete(n) }
        job.mindNodes.removeAll()
        try? modelContext.save()
        selected = nil
        scale = 1.0
        scaleBase = 1.0
        center(on: canvasCenter)
    }

    private func clamp(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.max(lo, Swift.min(hi, v))
    }

    // MARK: - Export & Share

    private func shareMindMap() {
        if let url = exportMindMapPDF(maxDimension: 2200) {
            // Present only once the URL is ready
            shareItem = ShareItem(url: url)
        } else {
            print("⚠️ Mind map export failed; no file to share.")
        }
    }

    /// Renders a **read-only** snapshot (no TextFields) to PDF and writes to a temp file.
    private func exportMindMapPDF(maxDimension: CGFloat = 2200) -> URL? {
        let exportSide = min(canvasSize, maxDimension)
        let scaleFactor = exportSide / canvasSize
        let fullSize = CGSize(width: canvasSize, height: canvasSize)

        // Try ImageRenderer first
        let exportView = snapshotContent
            .frame(width: fullSize.width, height: fullSize.height)
            .background(Color.clear)

        let swiftUIRenderer = ImageRenderer(content: exportView)
        swiftUIRenderer.scale = Double(scaleFactor)

        var snapshot: UIImage? = swiftUIRenderer.uiImage

        // Fallback: render via a HostingController if ImageRenderer fails (e.g. platform text issues)
        if snapshot == nil {
            let host = UIHostingController(rootView: exportView)
            host.view.bounds = CGRect(origin: .zero, size: fullSize)
            host.view.backgroundColor = .clear
            // Ensure layout before rendering the layer
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()

            let renderer = UIGraphicsImageRenderer(size: fullSize)
            snapshot = renderer.image { ctx in
                host.view.layer.render(in: ctx.cgContext)
            }

            // Downscale to requested size if needed
            if scaleFactor != 1.0, let img = snapshot {
                let scaledSize = CGSize(width: fullSize.width * scaleFactor, height: fullSize.height * scaleFactor)
                let scaledRenderer = UIGraphicsImageRenderer(size: scaledSize)
                snapshot = scaledRenderer.image { _ in
                    img.draw(in: CGRect(origin: .zero, size: scaledSize))
                }
            }
        }

        guard let image = snapshot else { return nil }

        // Make one-page PDF from the snapshot image
        let pageRect = CGRect(origin: .zero, size: image.size)
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())
        let pdfData = pdfRenderer.pdfData { ctx in
            ctx.beginPage()
            image.draw(in: pageRect)
        }

        let base = job.title.isEmpty ? "MindMap" : job.title
        let safe = base.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safe)_MindMap.pdf")

        do {
            try pdfData.write(to: url, options: .atomic)
            return url
        } catch {
            print("PDF write error: \(error)")
            return nil
        }
    }
}

// === AutoArrangeConfirmPanel, NodeBubble, NodeBubbleSnapshot, ActivityView remain unchanged ===
// (Keep your existing implementations below)


// MARK: - Auto-Arrange (unchanged)
private extension MindMapTabView {
    func autoArrangeTree() {
        guard let root = job.mindNodes.first(where: { $0.isRoot }) else { return }

        let leaves = leafCount(root)
        let levels = max(1, treeDepth(root))

        let baseNodeSpacing: CGFloat = 260
        let baseLevelGap: CGFloat    = 200

        let maxUsableWidth = canvasSize * 0.85
        let neededWidth = CGFloat(max(1, leaves - 1)) * baseNodeSpacing
        let widthScale = neededWidth > maxUsableWidth ? (maxUsableWidth / neededWidth) : 1.0
        let nodeSpacing = max(160, baseNodeSpacing * widthScale)

        let maxUsableHeight = canvasSize * 0.85
        let neededHeight = CGFloat(max(0, levels - 1)) * baseLevelGap
        let heightScale = neededHeight > maxUsableHeight ? (maxUsableHeight / neededHeight) : 1.0
        let levelGap = max(140, baseLevelGap * heightScale)

        var nextX: CGFloat = 0
        func assignPositions(_ node: MindNode, level: Int) {
            if node.children.isEmpty {
                nextX += nodeSpacing
                node.x = Double(nextX)
            } else {
                for c in node.children { assignPositions(c, level: level + 1) }
                if let first = node.children.first, let last = node.children.last {
                    let fx = CGFloat(first.x)
                    let lx = CGFloat(last.x)
                    node.x = Double((fx + lx) / 2.0)
                } else {
                    nextX += nodeSpacing
                    node.x = Double(nextX)
                }
            }
            node.y = Double(CGFloat(level) * levelGap)
        }

        nextX = 0
        assignPositions(root, level: 0)

        let xs = job.mindNodes.map { CGFloat($0.x) }
        let ys = job.mindNodes.map { CGFloat($0.y) }
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        let width = maxX - minX
        let height = maxY - minY
        let centerX = minX + width/2
        let centerY = minY + height/2
        let dx = canvasCenter.x - centerX
        let dy = canvasCenter.y - centerY

        for n in job.mindNodes {
            n.x = Double(CGFloat(n.x) + dx)
            n.y = Double(CGFloat(n.y) + dy)
        }

        try? modelContext.save()
        selected = root
        center(on: CGPoint(x: root.x, y: root.y))
    }

    func leafCount(_ node: MindNode) -> Int {
        if node.children.isEmpty { return 1 }
        return node.children.reduce(0) { $0 + leafCount($1) }
    }

    func treeDepth(_ node: MindNode) -> Int {
        if node.children.isEmpty { return 1 }
        return 1 + node.children.map(treeDepth(_:)).max()!
    }
}

// MARK: - Glass confirmation bubble (unchanged)
private struct AutoArrangeConfirmPanel: View {
    @Binding var isPresented: Bool
    var isBeta: Bool
    var onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 14) {
                Text("Re-arrange Mind Map?")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("This will re-arrange the entire map and is not reversible.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button("Cancel") {
                        withAnimation { isPresented = false }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button("Re-arrange") {
                        onConfirm()
                        withAnimation { isPresented = false }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.85))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
            .padding(.horizontal, 28)
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: isPresented)
    }

    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 18.0, *), isBeta {
            ZStack {
                Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.white.opacity(0.16), .clear],
                                       startPoint: .topTrailing, endPoint: .bottomLeading)
                    )
                    .blendMode(.plusLighter)
            }
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }
}

// MARK: - Live node bubble (editable)
private struct NodeBubble: View {
    @Environment(\.modelContext) private var modelContext
    var node: MindNode
    var isSelected: Bool
    var glassOn: Bool
    var focused: FocusState<UUID?>.Binding

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    private let bubbleWidth: CGFloat = 220
    private let minBubbleHeight: CGFloat = 52
    private let radius: CGFloat = 16
    private let titleFont: Font = .callout.weight(.semibold)
    private let hPad: CGFloat = 10
    private let vPad: CGFloat = 8

    var body: some View {
        let tint = color(for: node.colorCode ?? "teal")

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: node.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(node.isCompleted ? .green : .secondary)
                    .onTapGesture { node.isCompleted.toggle(); try? modelContext.save() }

                TextField("Idea", text: binding(\.title))
                    .textFieldStyle(.plain)
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused(focused, equals: node.id)
            }

            if !node.children.isEmpty {
                Text("\(node.children.count) node\(node.children.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .frame(width: bubbleWidth, alignment: .leading)
        .frame(minHeight: minBubbleHeight, alignment: .leading)
        .background(nodeBackground(tint: tint))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.8) :
                                      (glassOn ? Color.white.opacity(0.10) : Color.white.opacity(0.20)),
                        lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: glassOn ? .black.opacity(0.25) : .black.opacity(0.15),
                radius: glassOn ? 12 : 5, x: 0, y: glassOn ? 7 : 0)
    }

    @ViewBuilder
    private func nodeBackground(tint: Color) -> some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear
                    .glassEffect(.regular.tint(tint.opacity(0.5)),
                                 in: .rect(cornerRadius: radius))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                       startPoint: .topTrailing, endPoint: .bottomLeading)
                    )
                    .blendMode(.plusLighter)
            }
        } else if glassOn {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(tint.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                             startPoint: .topTrailing, endPoint: .bottomLeading))
                        .blendMode(.plusLighter)
                )
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.gradient)
        }
    }

    private func binding<T>(_ keyPath: ReferenceWritableKeyPath<MindNode, T>) -> Binding<T> {
        Binding(
            get: { node[keyPath: keyPath] },
            set: { node[keyPath: keyPath] = $0; try? modelContext.save() }
        )
    }
}

// MARK: - Snapshot node bubble (read-only label)
private struct NodeBubbleSnapshot: View {
    var node: MindNode
    var glassOn: Bool

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    private let bubbleWidth: CGFloat = 220
    private let minBubbleHeight: CGFloat = 52
    private let radius: CGFloat = 16
    private let titleFont: Font = .callout.weight(.semibold)
    private let hPad: CGFloat = 10
    private let vPad: CGFloat = 8

    var body: some View {
        let tint = color(for: node.colorCode ?? "teal")

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: node.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(node.isCompleted ? .green : .secondary)

                Text(node.title.isEmpty ? "Idea" : node.title)
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !node.children.isEmpty {
                Text("\(node.children.count) node\(node.children.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .frame(width: bubbleWidth, alignment: .leading)
        .frame(minHeight: minBubbleHeight, alignment: .leading)
        .background(nodeBackground(tint: tint))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(glassOn ? Color.white.opacity(0.10) : Color.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: glassOn ? .black.opacity(0.25) : .black.opacity(0.15),
                radius: glassOn ? 12 : 5, x: 0, y: glassOn ? 7 : 0)
    }

    @ViewBuilder
    private func nodeBackground(tint: Color) -> some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear
                    .glassEffect(.regular.tint(tint.opacity(0.5)),
                                 in: .rect(cornerRadius: radius))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                       startPoint: .topTrailing, endPoint: .bottomLeading)
                    )
                    .blendMode(.plusLighter)
            }
        } else if glassOn {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(tint.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                             startPoint: .topTrailing, endPoint: .bottomLeading))
                        .blendMode(.plusLighter)
                )
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.gradient)
        }
    }
}

// MARK: - Share sheet wrapper
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
